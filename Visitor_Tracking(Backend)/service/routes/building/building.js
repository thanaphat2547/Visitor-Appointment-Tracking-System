const config = require('../../configuration/connection');
const db = require("../../libraty/pgConnection");
const moment = require('moment');

//ดึงข้อมูลอาคารทั้งหมด
exports.getbuilding = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const script = `
            SELECT b_id, b_name, b_address, b_lat, b_long, b_radius, b_registered, b_modified 
            FROM tb_building 
            WHERE b_flag = '1' 
            ORDER BY b_id
        `;
        const result = await db.get(null, script, config);

        res.json({
            status: 'success',
            success: true,
            count: result.data ? result.data.length : 0,
            message: result.data && result.data.length > 0 ? 'ดึงข้อมูลอาคารสำเร็จ' : 'ไม่พบข้อมูลอาคาร',
            data: result.data || [],
            response_time: now 
        });
    } catch (err) {
        console.error('Error fetching building:', err);
        res.status(500).json({ error: 'ไม่สามารถดึงข้อมูลอาคารได้' });
    }
};

//เพิ่มข้อมูลอาคารใหม่
exports.putbuilding = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const { b_name, b_address, b_lat, b_long, b_radius } = req.body;

        if (!b_name || !b_address || !b_lat || !b_long || !b_radius) {
            return res.status(400).json({ error: 'กรุณากรอกข้อมูลให้ครบถ้วน' });
        }

        const checkScript = `
            SELECT b_name, b_lat, b_long 
            FROM tb_building 
            WHERE b_flag = '1' AND (b_name = $1 OR (b_lat = $2 AND b_long = $3))
        `;
        const checkResult = await db.get(null, checkScript, config, [b_name, b_lat, b_long]);

        if (checkResult.data && checkResult.data.length > 0) {
            const r = checkResult.data[0];
            if (r.b_name === b_name) return res.status(409).json({ message: 'ชื่ออาคารซ้ำ กรุณาใส่ใหม่' });
            return res.status(409).json({ message: 'พิกัดละติจูดและลองจิจูดนี้มีในระบบแล้ว' });
        }

        // สร้าง ID อัตโนมัติ (T001, T002...)
        const maxIdResult = await db.get(null, `SELECT MAX(b_id) as max_id FROM tb_building`, config);
        let seq = 1;
        if (maxIdResult.data && maxIdResult.data[0].max_id) {
            seq = parseInt(maxIdResult.data[0].max_id.slice(1)) + 1;
        }
        const newId = "T" + String(seq).padStart(3, '0');

        const insertScript = `
            INSERT INTO public."tb_building" 
            (b_id, b_name, b_lat, b_long, b_radius, b_address, b_modified, b_registered, b_flag)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, '1')
        `;
        
        const result = await db.get(null, insertScript, config, [
            newId, b_name, b_lat, b_long, b_radius, b_address, now, now
        ]);

        if (result.status === 'fail') {
            return res.status(500).json({ error: 'ไม่สามารถเพิ่มข้อมูลได้' + result.message });
        }
        
        res.json({ 
            status: 'success', 
            success: true,
            message: 'เพิ่มข้อมูลอาคารสำเร็จ', 
            data: { b_id: newId },
            response_time: now
        });

    } catch (err) {
        console.error('Error inserting building:', err);
        res.status(500).json({ error: 'Failed to insert building: ' + err.message });
    }
};

//แก้ไขข้อมูลอาคาร
exports.editbuilding = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const { b_id, b_name, b_address, b_lat, b_long, b_radius } = req.body;

        if (!b_id || !b_name || !b_address || !b_lat || !b_long || !b_radius) {
            return res.status(400).json({ error: 'กรุณากรอกข้อมูลให้ครบถ้วน' });
        }

        const checkScript = `
            SELECT b_id, b_name 
            FROM public."tb_building" 
            WHERE b_flag = '1' 
            AND (b_name = $1 OR (b_lat = $2 AND b_long = $3)) 
            AND b_id <> $4
        `;
        const checkResult = await db.get(null, checkScript, config, [b_name, b_lat, b_long, b_id]);

        if (checkResult.data && checkResult.data.length > 0) {
            const duplicate = checkResult.data[0];
            if (duplicate.b_name === b_name) {
                return res.status(409).json({ message: 'ชื่ออาคารนี้ถูกใช้งานแล้ว' });
            }
            return res.status(409).json({ message: 'พิกัดละติจูดและลองติจูดนี้ซ้ำกับอาคารอื่น' });
        }

        const updateScript = `
            UPDATE public."tb_building" 
            SET b_name = $1, b_lat = $2, b_long = $3, 
                b_radius = $4, b_address = $5, b_modified = $6
            WHERE b_id = $7 AND b_flag = '1'
        `;

        const result = await db.execute(null, updateScript, config, [
            b_name, b_lat, b_long, b_radius, b_address, now, b_id
        ]);

        if (result.code === true) {
            return res.status(500).json({ error: 'ข้อผิดพลาดในการแก้ไขข้อมูล' + result.message });
        }

        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'ไม่พบรหัสอาคารที่ต้องการแก้ไข' });
        }

        res.json({ 
            status: "success", 
            success: true,
            message: "แก้ไขข้อมูลอาคารสำเร็จ",
            response_time: now
        });

    } catch (err) {
        console.error('Error updating building:', err);
        res.status(500).json({ error: 'ไม่สามารถแก้ไขข้อมูลอาคารได้' });
    }
};

// ลบข้อมูลอาคาร
exports.deletebuilding = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const { b_id } = req.body;

        if (!b_id) {
            return res.status(400).json({ error: 'กรุณาระบุรหัสอาคารที่ต้องการลบ' });
        }

        const deleteScript = `
            UPDATE public."tb_building" 
            SET b_flag = '0', b_modified = $1 
            WHERE b_id = $2 AND b_flag = '1'
        `;
        
        const result = await db.execute(null, deleteScript, config, [now, b_id]);

        if (result.code === true) {
            return res.status(500).json({ error: 'ข้อผิดพลาดในการลบข้อมูล' + result.message });
        }

        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'ไม่พบรหัสอาคารที่ต้องการลบ หรืออาคารถูกลบไปก่อนหน้านี้แล้ว' });
        }

        res.json({ 
            status: "success", 
            success: true,
            message: "ลบข้อมูลอาคารสำเร็จ",
            response_time: now
        });

    } catch (err) {
        console.error('Error deleting building:', err);
        res.status(500).json({ error: 'ไม่สามารถลบข้อมูลอาคารได้' });
    }
};

// รายงานข้อมูลอาคาร
exports.reportBuilding = async (req, res) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    try {
        const script = `
            SELECT COUNT(*) as total_buildings 
            FROM public."tb_building" 
            WHERE b_flag = '1'
        `;
        const result = await db.get(null, script, config);
        
        res.json({
            status: 'success',
            success: true,
            message: 'รายงานข้อมูลอาคารสำเร็จ',
            data: result.data || [],
            response_time: now
        });
        
    } catch (err) {
        console.error('Error generating building report:', err);
        res.status(500).json({ 
            status: 'error',
            success: false,
            error: 'ไม่สามารถสร้างรายงานอาคารได้' 
        });
    }
};
