const config = require('../../configuration/connection');
const db = require("../../libraty/pgConnection");
const moment = require('moment');

// ตรวจสอบข้อมูลล็อกอินพนักงาน
exports.loginEmployee = async (req, res, next) => {
    try {
        const { username, password } = req.body;
        if (!username || !password) return res.status(400).json({ error: 'กรุณากรอกข้อมูลให้ครบ' });

        const script = `SELECT emp_id, emp_firstname, emp_lastname, role_id 
                        FROM public."tb_employee" 
                        WHERE emp_username = $1 AND emp_password = $2 AND emp_flag = '1'`;
        
        const result = await db.get(null, script, config, [username, password]);

        if (result.data && result.data.length > 0) {
            const user = result.data[0];
            req.user = {
                emp_id: user.emp_id,
                firstname: user.emp_firstname,
                lastname: user.emp_lastname,
                role_id: user.role_id
            };
            return next();
        } else {
            res.status(401).json({ error: 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง' });
        }
    } catch (err) {
        console.error('Login error:', err);
        res.status(500).json({ error: 'ข้อผิดพลาดภายในเซิร์ฟเวอร์' });
    }
};

// ดึงข้อมูลพนักงานทั้งหมด
exports.getEmployees = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const script = `
            SELECT emp_id, emp_firstname, emp_lastname, emp_email, emp_username, emp_phone, role_id, emp_department, emp_section, emp_position, emp_modified, emp_registered 
            FROM public."tb_employee" 
            WHERE emp_flag = '1'
            ORDER BY emp_id
        `;
        const result = await db.get(null, script, config);
        res.json({
            status: 'success',
            success: true,
            count: result.data ? result.data.length : 0,
            data: result.data || [],
            response_time: now
        });
    } catch (err) {
        res.status(500).json({ error: 'ไม่สามารถดึงข้อพนักงานได้' });
    }
};

exports.getEmployeeProfile = async (req, res) => {
    try {
        const userData = req.user;

        if (!userData) {
            return res.status(401).json({ success: false, message: 'ไม่พบข้อมูลผู้ใช้งาน' });
        }

        if (userData.role_id === 2) {
    const visitorId = userData.vis_id || userData.id;
    
    const visitorScript = `
        SELECT 
            v.vis_id, v.vis_firstname, v.vis_lastname, v.vis_phone, v.vis_email,
            b.bk_id, 
            b.appointment_start,  
            b.appointment_end,    
            b.purpose,            
            b.car_registration,  
            e.emp_firstname || ' ' || e.emp_lastname as staff_name,
            b.emp_department,     
            b.emp_position
        FROM public."tb_visitor" v
        JOIN public."tb_booking" b ON v.vis_id = b.vis_id
        LEFT JOIN public."tb_employee" e ON b.emp_id = e.emp_id
        WHERE v.vis_id = $1 AND v.vis_flag = '1'
        ORDER BY b.appointment_start DESC LIMIT 1
    `;

    const result = await db.get(null, visitorScript, config, [visitorId]);

    if (result.data && result.data.length > 0) {
        return res.json({
            success: true,
            data: {
                ...result.data[0],
                role_id: 2
            }
        });
    } else {
        return res.status(404).json({ success: false, message: 'ไม่พบข้อมูลการนัดหมาย' });
    }
}

        const emp_id = userData.emp_id;
        const script = `SELECT emp_id, emp_firstname, emp_lastname, emp_email, emp_username, emp_phone, role_id, emp_department, emp_section, emp_position 
                        FROM public."tb_employee" WHERE emp_id = $1 AND emp_flag = '1'`;
        
        const empResult = await db.get(null, script, config, [emp_id]);

        if (empResult.data && empResult.data.length > 0) {
            res.json({ success: true, data: empResult.data[0] });
        } else {
            res.status(404).json({ success: false, message: 'ไม่พบข้อมูลพนักงาน' });
        }
    } catch (err) {
        console.error('Get Profile Error:', err);
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};

// เพิ่มพนักงานใหม่
exports.putEmployee = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        let { emp_firstname, emp_lastname, emp_email, emp_username, emp_password, emp_phone, role_id, emp_department, emp_section, emp_position, } = req.body;
        if (!emp_firstname || !emp_lastname || !emp_email || !emp_username || !emp_password || !emp_phone || !emp_department || !emp_section || !emp_position ) {
            return res.status(400).json({ error: 'กรุณากรอกข้อมูลสำคัญให้ครบถ้วน' });
        }

        // ลบอักขระพิเศษออกจากเบอร์โทรศัพท์ (เหลือแค่ตัวเลข 10 หลัก)
        emp_phone = emp_phone.replace(/\D/g, "");

        // สร้าง ID อัตโนมัติ E00001
        const maxIdResult = await db.get(null, `SELECT MAX(emp_id) AS max_id FROM public."tb_employee"`, config);
        let seq = 1;
        if (maxIdResult.data && maxIdResult.data[0].max_id) {
            seq = parseInt(maxIdResult.data[0].max_id.slice(1)) + 1;
        }
        const newEmpId = "E" + String(seq).padStart(5, '0');

        // เช็คซ้ำ
        const checkScript = `SELECT emp_id FROM public."tb_employee" WHERE emp_flag = '1' AND (emp_username = $1 OR emp_email = $2)`;
        const checkResult = await db.get(null, checkScript, config, [emp_username, emp_email]);
        if (checkResult.data && checkResult.data.length > 0) {
            return res.status(409).json({ message: 'ชื่อผู้ใช้หรืออีเมลนี้มีในระบบแล้ว' });
        }

        const insertScript = `
            INSERT INTO public."tb_employee" 
            (emp_id, emp_firstname, emp_lastname, emp_email, emp_username, emp_password, emp_phone, emp_registered, emp_modified, role_id, emp_department, emp_section, emp_position, emp_flag)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, '1')
        `;
        const result = await db.execute(null, insertScript, config, [newEmpId, emp_firstname, emp_lastname, emp_email, emp_username, emp_password, emp_phone, now, now, role_id || '1', emp_department, emp_section, emp_position]);

        if (result.code) {
            return res.status(500).json({ message: 'ไม่สามารถเพิ่มข้อมูลได้: ' + result.message });
        }

        res.json({ status: 'success', message: 'ลงทะเบียนพนักงานสำเร็จ', emp_id: newEmpId });
    } catch (err) {
        res.status(500).json({ error: 'ไม่สามารถเพิ่มข้อมูลได้' + err.message });
    }
};

// แก้ไขข้อมูลพนักงาน
exports.editEmployee = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        let { emp_id, emp_firstname, emp_lastname, emp_email, emp_password, emp_phone, emp_department, emp_section, emp_position } = req.body;
        if (!emp_id) return res.status(400).json({ error: 'Missing emp_id' });

        // ลบอักขระพิเศษออกจากเบอร์โทรศัพท์
        emp_phone = emp_phone.replace(/\D/g, "");

        const updateScript = `
            UPDATE public."tb_employee" 
            SET emp_firstname = $1, emp_lastname = $2, emp_email = $3, emp_phone = $4, emp_department = $5, emp_section = $6, emp_position = $7, emp_modified = $8 , emp_password = COALESCE(NULLIF($9, ''), emp_password)
            WHERE emp_id = $10 AND emp_flag = '1'
        `;
        const result = await db.execute(null, updateScript, config, [emp_firstname, emp_lastname, emp_email, emp_phone, emp_department, emp_section, emp_position, now, emp_password, emp_id]);
        
        if (result.code) {
            return res.status(500).json({ message: 'ไม่สามารถแก้ไขข้อมูลได้: ' + result.message });
        }
        
        if (result.rowCount === 0) return res.status(404).json({ message: 'ไม่พบพนักงาน' });
        res.json({ status: "success", message: "แก้ไขข้อมูลพนักงานสำเร็จ" });
    } catch (err) {
        res.status(500).json({ error: 'ไม่สามารถแก้ไขข้อมูลพนักงานได้' });
    }
};

// ลบพนักงาน
exports.deleteEmployee = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const { emp_id } = req.body;
        const deleteScript = `UPDATE public."tb_employee" SET emp_flag = '0', emp_modified = $1 WHERE emp_id = $2`;
        const result = await db.execute(null, deleteScript, config, [now, emp_id]);
        
        if (result.rowCount === 0) return res.status(404).json({ message: 'ไม่พบพนักงานที่ต้องการลบ' });
        res.json({ status: "success", message: "ลบพนักงานสำเร็จ" });
    } catch (err) {
        console.error('Error:', err);
        res.status(500).json({ error: 'ไม่สามารถลบข้อมูลพนักงานได้' });
    }
};

// รายงานจำนวนพนักงานทั้งหมด
exports.reportEmployee = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const script = `SELECT COUNT(*) as total_employees FROM public."tb_employee" WHERE emp_flag = '1'`;
        const result = await db.get(null, script, config);
        
        res.json({
            status: 'success',
            success: true,
            message: 'รายงานข้อมูลพนักงานสำเร็จ',
            data: result.data || [],
            response_time: now
        });
    } catch (err) {
        console.error('Error generating employee report:', err);
        res.status(500).json({ 
            status: 'error',
            success: false,
            error: 'ไม่สามารถสร้างรายงานพนักงานได้' 
        });
    }
};