const config = require('../../configuration/connection');
const db = require("../../libraty/pgConnection");
const bcrypt = require('bcrypt');
const moment = require('moment');

const getCredentials = (req) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Basic ')) {
    const base64 = authHeader.split(' ')[1] || '';
    const credentials = Buffer.from(base64, 'base64').toString('ascii');
    const idx = credentials.indexOf(':');
    if (idx !== -1) return { user: credentials.slice(0, idx), pass: credentials.slice(idx + 1) };
  }
  return null;
};

const authMiddleware = (allowedRoles = []) => {
  return async (req, res, next) => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    const creds = getCredentials(req);

    if (!creds) return res.status(401).json({ success: false, message: "กรุณาเข้าสู่ระบบ", timestamp: now });

    try {
      // ตรวจสอบเงื่อนไข Visitor (รหัสผ่านเริ่มด้วย BK)
      if (creds.pass.toUpperCase().startsWith('BK')) {
        const visitorScript = `
          SELECT v.vis_id, v.vis_firstname, v.vis_lastname, v.vis_phone, b.bk_id
          FROM tb_visitor v
          JOIN tb_booking b ON v.vis_id = b.vis_id
          WHERE REPLACE(v.vis_phone, '-', '') = $1 
            AND UPPER(b.bk_id) = UPPER($2) 
            AND v.vis_flag = '1' 
          LIMIT 1
        `;
        
        const cleanUserPhone = creds.user.replace(/-/g, '');
        const result = await db.get(null, visitorScript, config, [cleanUserPhone, creds.pass]);

        if (result.data && result.data.length > 0) {
          const v = result.data[0];
          req.user = { 
            user_id: v.vis_id,
            vis_id: v.vis_id, 
            firstname: v.vis_firstname, 
            lastname: v.vis_lastname, 
            role_id: 2, 
            bk_id: v.bk_id,
            role: 'visitor' 
          };
          return next();
        }
      }

      // ตรวจสอบเงื่อนไข Employee (Admin / Officer)
      const employeeScript = `SELECT * FROM tb_employee WHERE emp_username = $1 AND emp_flag = '1'`;
      const empResult = await db.get(null, employeeScript, config, [creds.user]);

      if (empResult.data && empResult.data.length > 0) {
        const user = empResult.data[0];
        const roleId = parseInt(user.role_id);

        const isRealPass = user.emp_password && user.emp_password.startsWith('$2') 
          ? await bcrypt.compare(creds.pass, user.emp_password) 
          : (creds.pass === user.emp_password);
        
        // ลบขีดทั้งคู่ก่อนเทียบเบอร์โทร
        const isPhonePass = (creds.pass.replace(/-/g, '') === user.emp_phone.replace(/-/g, ''));

        let canLogin = false;
        if (roleId === 0) canLogin = isRealPass;
        else if (roleId === 1) canLogin = isRealPass || isPhonePass;

        if (canLogin) {
          if (allowedRoles.length > 0 && !allowedRoles.includes(roleId)) {
            return res.status(403).json({ success: false, message: "ไม่มีสิทธิ์เข้าถึง" });
          }

          req.user = {
            user_id: user.emp_id,
            emp_id: user.emp_id,
            firstname: user.emp_firstname,
            lastname: user.emp_lastname,
            role_id: roleId,
            role: 'officer'
          };
          return next();
        }
      }

      return res.status(401).json({ success: false, message: "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง", timestamp: now });

    } catch (err) {
      console.error('Auth Error:', err);
      res.status(500).json({ success: false, message: "เกิดข้อผิดพลาดที่เซิร์ฟเวอร์" });
    }
  };
};

const isAdmin = (req, res, next) => {
  if (!req.user || req.user.role_id !== 0) return res.status(403).json({ message: "เฉพาะ Admin" });
  next();
};

const isOfficer = (req, res, next) => {
  if (!req.user || req.user.role_id !== 1) return res.status(403).json({ message: "เฉพาะ Officer" });
  next();
};

module.exports = { authMiddleware, isAdmin, isOfficer };