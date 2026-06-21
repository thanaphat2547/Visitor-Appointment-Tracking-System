const config = require('../../configuration/connection');
const db = require("../../libraty/pgConnection");
const moment = require('moment');

// ดึงข้อมูล Beacon ทั้งหมด
exports.getBeacons = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const script = `
            SELECT 
                bc.bc_id, 
                bc.bc_name, 
                bc.bc_uuid, 
                bc.b_id, 
                bl.b_name -- เพิ่มชื่ออาคารจากการ JOIN
            FROM public."tb_beacon" bc
            LEFT JOIN public."tb_building" bl ON bc.b_id = bl.b_id -- เชื่อมกับตารางอาคาร
            WHERE bc.bc_flag = '1'
            ORDER BY bc.bc_id
        `;
        const result = await db.get(null, script, config);
        res.json({
            status: 'success',
            success: true,
            data: result.data || [],
            response_time: now
        });
    } catch (err) {
        res.status(500).json({ error: 'ไม่สามารถดึงข้อมูลอุปกรณ์บีคอนได้' });
    }
};

// เพิ่ม Beacon
exports.putBeacon = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const { bc_name, bc_uuid, b_id } = req.body; 
        
        // ตรวจสอบค่าว่าง
        if (!bc_name || !bc_uuid || !b_id) {
            return res.status(400).json({ error: 'กรุณากรอกข้อมูลให้ครบถ้วน' });
        }

        // ตรวจสอบ UUID ซ้ำ (ในบีคอนที่ยังใช้งานอยู่ bc_flag = '1')
        const checkUuidScript = `SELECT bc_id FROM public."tb_beacon" WHERE bc_uuid = $1 AND bc_flag = '1'`;
        const uuidExists = await db.get(null, checkUuidScript, config, [bc_uuid]);
        
        if (uuidExists.data && uuidExists.data.length > 0) {
            return res.status(409).json({ 
                success: false,
                message: 'UUID นี้ถูกลงทะเบียนกับบีคอนเครื่องอื่นแล้ว'
            });
        }

        // ตรวจสอบชื่อซ้ำในอาคารเดียวกัน
        const checkNameScript = `SELECT bc_id FROM public."tb_beacon" WHERE bc_name = $1 AND b_id = $2 AND bc_flag = '1'`;
        const nameExists = await db.get(null, checkNameScript, config, [bc_name, b_id]);

        if (nameExists.data && nameExists.data.length > 0) {
            return res.status(409).json({ 
                success: false,
                error: 'ชื่อบีคอนนี้มีอยู่แล้วในอาคารที่เลือก' 
            });
        }

        // สร้าง bc_id ใหม่
        const maxIdResult = await db.get(null, `SELECT MAX(bc_id) AS max_id FROM public."tb_beacon"`, config);
        let seq = 1;
        if (maxIdResult.data && maxIdResult.data[0].max_id) {
            seq = parseInt(maxIdResult.data[0].max_id.slice(1)) + 1;
        }
        const bcid = "B" + String(seq).padStart(3, '0');

        const insertScript = `
            INSERT INTO public."tb_beacon" 
            (bc_id, bc_name, bc_uuid, b_id, bc_modified, bc_registered, bc_flag)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
        `;
        
        await db.execute(null, insertScript, config, [bcid, bc_name, bc_uuid, b_id, now, now, '1']);

        res.json({ 
            success: true, 
            message: 'เพิ่มบีคอนสำเร็จ', 
            bc_id: bcid 
        });

    } catch (err) {
        console.error("Put Beacon Error:", err);
        res.status(500).json({ error: 'ไม่สามารถเพิ่มข้อมูลได้: ' + err.message });
    }
};

// แก้ไข Beacon
exports.editBeacon = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const { bc_id, bc_name, bc_uuid, b_id } = req.body;

        if (!bc_id || !bc_name || !bc_uuid || !b_id) return res.status(400).json({ error: 'กรุณากรอกข้อมูลให้ครบถ้วน' });

        const checkScript = `
            SELECT bc_uuid 
            FROM public."tb_beacon" 
            WHERE bc_flag = '1' 
            AND bc_uuid = $1 
            AND bc_id <> $2
        `;
        const checkResult = await db.get(null, checkScript, config, [bc_uuid, bc_id]);
        if (checkResult.data && checkResult.data.length > 0) {
            return res.status(409).json({ message: 'UUID นี้ซ้ำกับบีคอนเครื่องอื่น' });
        }

        const checkNameScript = `
            SELECT bc_id FROM public."tb_beacon" 
            WHERE bc_flag = '1' 
            AND bc_name = $1 
            AND b_id = $2
            AND bc_id <> $3
        `;
        const checkNameResult = await db.get(null, checkNameScript, config, [bc_name, b_id, bc_id]);
        if (checkNameResult.data && checkNameResult.data.length > 0) {
            return res.status(409).json({ error: 'ชื่อบีคอนนี้ซ้ำกับบีคอนอื่นในอาคารนี้' });
        }

        const updateScript = `
            UPDATE public."tb_beacon" 
            SET bc_name = $1, bc_uuid = $2, b_id = $3, bc_modified = $4
            WHERE bc_id = $5 AND bc_flag = '1'
        `;
        
        const result = await db.execute(null, updateScript, config, [bc_name, bc_uuid, b_id, now, bc_id]);

        if (result.code === true) {
            return res.status(500).json({ error: 'ข้อผิดพลาดในการแก้ไขข้อมูล' + result.message });
        }

        if (result.rowCount === 0) return res.status(404).json({ message: 'ไม่พบบีคอนที่ต้องการแก้ไข' });
        res.json({ 
            status: "success", 
            message: "แก้ไขข้อมูลบีคอนสำเร็จ", 
            response_time: now 
        });

    } catch (err) {
        console.error('Error updating beacon:', err);
        res.status(500).json({ error: 'ไม่สามารถแก้ไขข้อมูลบีคอนได้' });
    }
};

// ลบ Beacon
exports.deleteBeacon = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const { bc_id } = req.body;

        if (!bc_id) return res.status(400).json({ error: 'กรุณากรอกข้อมูลให้ครบถ้วน' });

        const deleteBeacon = `
            UPDATE tb_beacon 
            SET bc_flag = '0', bc_modified = $1 
            WHERE bc_id = $2
        `;

        const resultBeacon = await db.execute(null, deleteBeacon, config, [now, bc_id]);

        if (resultBeacon.code === true) {
            return res.status(500).json({ error: 'ข้อผิดพลาดในการลบข้อมูล' + resultBeacon.message });
        }

        res.json({ status: "success", 
            message: "ลบข้อมูลบีคอนสำเร็จ", 
            response_time: now 
        });

    } catch (err) {
        console.error('Error deleting beacon:', err);
        res.status(500).json({ error: 'ไม่สามารถลบบีคอนได้' });
    }
};

// รายงานข้อมูล Beacon
exports.reportBeacon = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const script = `
            SELECT COUNT(*) as total_beacons 
            FROM tb_beacon 
            WHERE bc_flag = '1'
        `;
        const result = await db.get(null, script, config);
        
        res.json({status: 'success',
            success: true,
            message: 'รายงานข้อมูลบีคอนสำเร็จ',
            data: result.data || [],
            response_time: now
        });
        
    } catch (err) {
        console.error('Error generating beacon report:', err);
        res.status(500).json({ error: 'ไม่สามารถสร้างรายงานบีคอนได้' });
    }
};