const config = require('../../configuration/connection');
const db = require("../../libraty/pgConnection");
const moment = require('moment');

// ดึงข้อมูลผู้มาติดต่อทั้งหมด
exports.getVisitors = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const script = `
            SELECT 
                v.*, 
                e.emp_firstname || ' ' || e.emp_lastname as creator_name
            FROM public."tb_visitor" v
            LEFT JOIN public."tb_employee" e ON v.created_by = e.emp_id
            WHERE v.vis_flag = '1'
            ORDER BY v.vis_id
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
        res.status(500).json({ error: 'ไม่สามารถดึงข้อมูลผู้มาติดต่อได้' });
    }
};

// ลงทะเบียนผู้มาติดต่อใหม่
exports.putVisitor = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const { vis_firstname, vis_lastname, vis_email, vis_phone } = req.body; 

        // ดึง ID ของผู้ใช้งานที่ล็อกอินอยู่
        const creatorId = req.user ? req.user.emp_id : 'Unknown';

        if (!vis_firstname || !vis_lastname || !vis_email || !vis_phone) {
            return res.status(400).json({ error: 'กรุณากรอกข้อมูลพื้นฐานให้ครบถ้วน' });
        }

        // สร้าง ID อัตโนมัติ (V00001)
        const maxIdResult = await db.get(null, `SELECT MAX(vis_id) AS max_id FROM public."tb_visitor"`, config);
        let seq = 1;
        if (maxIdResult.data && maxIdResult.data[0].max_id) {
            seq = parseInt(maxIdResult.data[0].max_id.slice(1)) + 1;
        }
        const newVisId = "V" + String(seq).padStart(5, '0');

        // เช็คอีเมลซ้ำ
        const checkScript = `SELECT vis_id FROM public."tb_visitor" WHERE vis_flag = '1' AND vis_email = $1`;
        const checkResult = await db.get(null, checkScript, config, [vis_email]);
        if (checkResult.data && checkResult.data.length > 0) {
            return res.status(409).json({ message: 'อีเมลนี้ถูกลงทะเบียนไว้แล้ว' });
        }

        const insertScript = `
            INSERT INTO public."tb_visitor" 
            (vis_id, vis_firstname, vis_lastname, vis_email, vis_phone, vis_registered, vis_flag, created_by)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        `;
        await db.execute(null, insertScript, config, [
            newVisId, vis_firstname, vis_lastname, vis_email, vis_phone, now, '1', creatorId 
        ]);

        res.json({ status: 'success', message: 'ลงทะเบียนผู้ติดต่อสำเร็จ', vis_id: newVisId });
    } catch (err) {
        res.status(500).json({ error: 'ไม่สามารถเพิ่มข้อมูลได้' + err.message });
    }
};

// แก้ไขข้อมูลผู้มาติดต่อ
exports.patchVisitor = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const { vis_id, vis_firstname, vis_lastname, vis_email, vis_phone} = req.body;
        if (!vis_id) return res.status(400).json({ error: 'Missing vis_id' });

        const updateScript = `
            UPDATE public."tb_visitor" 
            SET vis_firstname = $1, vis_lastname = $2, vis_email = $3, vis_phone = $4
            WHERE vis_id = $5 AND vis_flag = '1'
        `;
        const result = await db.execute(null, updateScript, config, [vis_firstname, vis_lastname, vis_email, vis_phone, vis_id]);
        
        if (result.rowCount === 0) return res.status(404).json({ message: 'ไม่พบข้อมูลผู้ติดต่อ' });
        res.json({ status: "success", message: "อัปเดตข้อมูลผู้ติดต่อสำเร็จ" });
    } catch (err) {
        res.status(500).json({ error: 'ไม่สามารถแก้ไขข้อมูลได้' });
    }
};

// ลบข้อมูลผู้มาติดต่อ
exports.deleteVisitor = async (req, res) => {
    try {
        const { vis_id } = req.body;
        const deleteScript = `UPDATE public."tb_visitor" SET vis_flag = '0' WHERE vis_id = $1`;
        const result = await db.execute(null, deleteScript, config, [vis_id]);
        
        if (result.rowCount === 0) return res.status(404).json({ message: 'ไม่พบข้อมูลที่ต้องการลบ' });
        res.json({ status: "success", message: "ลบข้อมูลผู้ติดต่อสำเร็จ" });
    } catch (err) {
        res.status(500).json({ error: 'ไม่สามารถลบข้อมูลได้' });
    }
};

// รายงานจำนวนผู้มาติดต่อ
exports.reportVisitor = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const script = `SELECT COUNT(*) as total_visitors FROM public."tb_visitor" WHERE vis_flag = '1'`;
        const result = await db.get(null, script, config);
        res.json({
            status: 'success',
            success: true,
            message: 'รายงานข้อมูลผู้ติดต่อสำเร็จ',
            data: result.data || [],
            response_time: now
        });
    } catch (err) {
        console.error('Error:', err);
        res.status(500).json({ error: 'ไม่สามารถสร้างรายงานผู้มาติดต่อได้' });
    }
};
