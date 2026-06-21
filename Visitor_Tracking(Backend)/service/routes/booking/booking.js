const config = require('../../configuration/connection');
const db = require("../../libraty/pgConnection");
const moment = require('moment');

const SIGNAL_TIMEOUT_SECONDS = 300; // 5 minutes
const LATE_GRACE_PERIOD_MINUTES = 30;
const EXIT_TIMEOUT_SECONDS = 900; // 15 minutes

// Cron job: อัพเดทสถานะการนัดหมายอัตโนมัติ
async function updateBookingStatuses() {
    try {
        // 1. Update สถานะ '3' (สาย - Late): เลยเวลาเริ่ม 30 นาที แต่ยังไม่มาเจอ
        const updateLate = `
            UPDATE public."tb_booking" bk
            SET bk_status = '3'
            WHERE bk.bk_status = '0'
              AND NOW() > bk.appointment_start + INTERVAL '${LATE_GRACE_PERIOD_MINUTES} minutes'
              AND NOT EXISTS (
                  SELECT 1 FROM public."tb_location" lb
                  WHERE lb.bk_id = bk.bk_id
              )
        `;
        await db.execute(null, updateLate, config);

        // 2. Update สถานะ '1' (มาถึงแล้ว - Arrived): แสกนเจอบีคอน
        const updateArrived = `
            UPDATE public."tb_booking" bk
            SET bk_status = '1',
                bk_checkin = COALESCE(bk.bk_checkin, NOW())
            WHERE bk.bk_status IN ('0', '3')
              AND EXISTS (
                  SELECT 1 FROM public."tb_location" lb
                  WHERE lb.bk_id = bk.bk_id
                    AND EXTRACT(EPOCH FROM (NOW() - lb.lobc_time_in)) <= $1
              )
              AND NOW() >= (bk.appointment_start - INTERVAL '30 minutes')
        `;
        await db.execute(null, updateArrived, config, [SIGNAL_TIMEOUT_SECONDS]);

        // 3. Update สถานะ '2' (เสร็จสิ้น - Finished): สัญญาณหายไปเกิน 15 นาที
        const updateFinished = `
            UPDATE public."tb_booking" bk
            SET "bk_status" = '2',
                "bk_checkout" = COALESCE(bk."bk_checkout", NOW())
            WHERE bk."bk_status" = '1'
              AND NOW() > bk."appointment_end" + INTERVAL '30 minutes'
        `;
        await db.execute(null, updateFinished, config);

        console.log(`[${moment().format('HH:mm:ss')}] CronJob: Booking statuses updated.`);
    } catch (error) {
        console.error("CronJob Error:", error);
    }
}

// ดึงข้อมูลการนัดหมายทั้งหมด
async function getBookings(req, res) {
    const { status, startDate, endDate, emp_id, bk_id, vis_id, role_id } = req.query;

    try {
        let params = [];
        let conditions = ["1=1"];

        if (role_id) {
            const role = parseInt(role_id);
            if (role === 1) {
                params.push(emp_id);
                conditions.push(`bk.emp_id = $${params.length}`);
            } else if (role === 2) {
                params.push(bk_id);
                conditions.push(`bk.bk_id = $${params.length}`);
            }
        }

        if (startDate && endDate) {
            params.push(startDate, endDate);
            conditions.push(`bk.appointment_start::date BETWEEN $${params.length - 1} AND $${params.length}`);
        } else if (startDate) {
            params.push(startDate);
            conditions.push(`bk.appointment_start::date = $${params.length}`);
        }

        const script = `
            SELECT bk.*,
                v.vis_firstname || ' ' || v.vis_lastname as visitor_name,
                v.vis_email,
                v.vis_phone,
                e.emp_firstname || ' ' || e.emp_lastname as employee_name,
                e.emp_email,
                e.emp_phone,
                e.emp_department,
                e.emp_section,
                e.emp_position,
                b.b_name as building_name,
                b.b_lat,
                b.b_long,
                lb.bc_id,
                lb.loc_lat as lobc_lat,
                lb.loc_long as lobc_long,
                EXTRACT(EPOCH FROM (NOW() - lb.lobc_time_in)) as seconds_since_update
            FROM public."tb_booking" bk
            LEFT JOIN public."tb_visitor" v ON bk.vis_id = v.vis_id
            LEFT JOIN public."tb_employee" e ON bk.emp_id = e.emp_id
            LEFT JOIN public."tb_building" b ON bk.b_id = b.b_id
            LEFT JOIN public."tb_location" lb ON bk.bk_id = lb.bk_id
            WHERE ${conditions.join(' AND ')}
            ${status && status !== 'all' ? (() => {
                params.push(status);
                return `AND bk.bk_status = $${params.length}`;
            })() : ''}
            ORDER BY bk.appointment_start ASC
        `;

        const result = await db.get(null, script, config, params);
        res.json({ status: 'success', success: true, data: result.data || [] });
    } catch (err) {
        console.error("Error in getBookings:", err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
}


// สร้าง ID การนัดหมายที่ไม่ซ้ำกัน
async function generateUniqueBookingId() {
    let isUnique = false;
    let newId = '';
    while (!isUnique) {
        const randomNumbers = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
        newId = `BK${randomNumbers}`;
        const check = await db.get(null, `SELECT bk_id FROM public."tb_booking" WHERE bk_id = $1`, config, [newId]);
        if (!check.data || check.data.length === 0) isUnique = true;
    }
    return newId;
}

// เพิ่มการนัดหมายใหม่
async function putBooking(req, res) {
    try {
        const {
            vis_id, emp_id, b_id, purpose, car_registration,
            appointment_start, appointment_end,
            emp_department, emp_section, emp_position
        } = req.body;

        const checkScript = `
            SELECT bk_id FROM public."tb_booking"
            WHERE emp_id = $1
              AND bk_status <> '4'
              AND ((appointment_start, appointment_end) OVERLAPS ($2::timestamp, $3::timestamp))
        `;
        const checkResult = await db.get(null, checkScript, config, [emp_id, appointment_start, appointment_end]);

        if (checkResult.data && checkResult.data.length > 0) {
            return res.status(409).json({
                message: 'พนักงานมีนัดหมายอื่นในช่วงเวลาดังกล่าวแล้ว'
            });
        }

        const newBkId = await generateUniqueBookingId();
        const insertScript = `
            INSERT INTO public."tb_booking"
            (bk_id, vis_id, emp_id, b_id, purpose, car_registration, appointment_start, appointment_end,
             bk_status, emp_department, emp_section, emp_position)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, '0', $9, $10, $11)
        `;

        await db.execute(null, insertScript, config, [
            newBkId, vis_id, emp_id, b_id, purpose, car_registration,
            appointment_start, appointment_end,
            emp_department, emp_section, emp_position
        ]);

        res.json({ status: 'success', message: 'สร้างการนัดหมายสำเร็จ' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'ไม่สามารถบันทึกได้' });
    }
}

// แก้ไขข้อมูลการนัดหมาย
async function editBooking(req, res) {
    try {
        const { bk_id, purpose, car_registration, appointment_start, appointment_end, b_id } = req.body;
        const now = moment();
        const newStart = moment(appointment_start);
        let newStatus = null;

        if (newStart.isAfter(now)) {
            newStatus = '0';
        }

        const updateScript = `
            UPDATE public."tb_booking"
            SET purpose = $1,
                car_registration = $2,
                appointment_start = $3,
                appointment_end = $4,
                b_id = $5,
                bk_status = CASE WHEN $7::text IS NOT NULL THEN $7 ELSE bk_status END
            WHERE bk_id = $6 AND bk_status IN ('0', '1', '3')
        `;

        await db.execute(null, updateScript, config, [
            purpose,
            car_registration,
            appointment_start,
            appointment_end,
            b_id,
            bk_id,
            newStatus
        ]);

        res.json({ status: 'success', message: 'แก้ไขข้อมูลสำเร็จและรีเซ็ตสถานะแล้ว' });
    } catch (err) {
        console.error('Edit Error:', err);
        res.status(500).json({ error: 'ไม่สามารถแก้ไขข้อมูลได้' });
    }
}

// เช็คอิน
async function checkInBooking(req, res) {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const { bk_id } = req.body;
        if (!bk_id) return res.status(400).json({ error: 'Missing bk_id' });

        const script = `
            UPDATE public."tb_booking"
            SET bk_checkin = $1, bk_status = '1'
            WHERE bk_id = $2 AND bk_status IN ('0', '3')
        `;
        const result = await db.execute(null, script, config, [now, bk_id]);

        if (result.rowCount === 0) return res.status(404).json({ message: 'ไม่พบข้อมูลนัดหมาย หรือมีการเช็คอินไปแล้ว' });
        res.json({ status: 'success', message: 'เช็คอินสำเร็จ', checkin_time: now });
    } catch (err) {
        res.status(500).json({ error: 'ไม่สามารถเช็คอินได้' });
    }
}

// เช็คเอาท์
async function checkOutBooking(req, res) {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const { bk_id } = req.body;
        const script = `
            UPDATE public."tb_booking"
            SET bk_checkout = $1, bk_status = '2'
            WHERE bk_id = $2 AND bk_status = '1'
        `;
        const result = await db.execute(null, script, config, [now, bk_id]);

        if (result.rowCount === 0) return res.status(404).json({ message: 'ไม่พบข้อมูล หรือยังไม่ได้เช็คอิน' });
        res.json({ status: 'success', message: 'เช็คเอาท์สำเร็จ', checkout_time: now });
    } catch (err) {
        res.status(500).json({ error: 'ไม่สามารถเช็คเอาท์ได้' });
    }
}

// ยกเลิกการนัดหมาย
async function cancelBooking(req, res) {
    try {
        const { bk_id } = req.body;
        const cancelScript = `UPDATE public."tb_booking" SET bk_status = '4' WHERE bk_id = $1`;
        const result = await db.execute(null, cancelScript, config, [bk_id]);

        if (result.rowCount === 0) return res.status(404).json({ message: 'ไม่พบรหัสการนัดหมาย' });
        res.json({ status: 'success', message: 'ยกเลิกการนัดหมายเรียบร้อยแล้ว' });
    } catch (err) {
        res.status(500).json({ error: 'ไม่สามารถยกเลิกได้' });
    }
}

// สร้างรายงานการนัดหมายวันนี้
async function reportBooking(req, res) {
    try {
        const script = `
            SELECT
                COUNT(*) as total_all,
                COUNT(*) FILTER (WHERE bk_status = '0') as pending,
                COUNT(*) FILTER (WHERE bk_status = '1') as arrived,
                COUNT(*) FILTER (WHERE bk_status = '2') as finished,
                COUNT(*) FILTER (WHERE bk_status = '3') as late,
                COUNT(*) FILTER (WHERE bk_status = '4') as cancelled
            FROM public."tb_booking"
            WHERE appointment_start::date = CURRENT_DATE
        `;
        const result = await db.get(null, script, config);

        res.json({
            status: 'success',
            success: true,
            data: result.data || []
        });
    } catch (err) {
        console.error('Error:', err);
        res.status(500).json({ error: 'ไม่สามารถสร้างรายงานได้' });
    }
}

module.exports = {
    updateBookingStatuses,
    getBookings,
    putBooking,
    editBooking,
    checkInBooking,
    checkOutBooking,
    cancelBooking,
    reportBooking,
};