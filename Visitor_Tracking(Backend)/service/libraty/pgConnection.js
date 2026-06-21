const { Pool } = require('pg');

// ฟังก์ชันสำหรับรันคำสั่งทั่วไป
exports.execute = async (database, script, connectionstring, params = []) => {
  const pool = new Pool(connectionstring);
  try {
    const result = await pool.query(script, params);
    return { code: false, message: "", rowCount: result.rowCount };
  } catch (e) {
    console.error("Execute Error:", e.message);
    return { code: true, message: e.message, rowCount: 0 };
  } finally {
    await pool.end();
  }
};

// ฟังก์ชันสำหรับเพิ่มข้อมูลใหม่
exports.create = async (database, script, connectionstring, params = []) => {
  const pool = new Pool(connectionstring);
  try {
    await pool.query(script, params);
    return { code: false, message: "" };
  } catch (e) {
    if (e.message.indexOf("unique") != -1 || e.message.indexOf("already") != -1) {
      return { code: false, message: "" };
    } else {
      console.error("Create Error:", e.message);
      return { code: true, message: e.message };
    }
  } finally {
    await pool.end();
  }
};

// ฟังก์ชันสำหรับดึงข้อมูล
exports.get = async (database, script, connectionstring, params = []) => {
  const pool = new Pool(connectionstring);
  try {
    const result = await pool.query(script, params);
    if (result.rows && result.rows.length > 0) {
      return { code: false, data: result.rows };
    } else {
      return { code: false, data: [] };
    }
  } catch (e) {
    console.error("Get Error:", e.message);
    return { code: true, message: e.message };
  } finally {
    await pool.end();
  }
};