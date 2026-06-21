const config = require("../../configuration/connection");
const db = require("../../libraty/pgConnection");
const moment = require("moment");

exports.postCountBeaconForPlace = async (req, res) => {
  try {
    let { b_id, start_date, end_date } = req.body;

    if (!b_id || !start_date || !end_date) {
      return res.status(400).json({
        message: "ไม่สามารถดึงข้อมูลได้, เนื่องจากข้อมูลพารามิเตอร์ไม่ถูกต้อง",
      });
    }

    let script = `
        SELECT 
            b.b_id, 
            b.b_name, 
            b.b_lat, 
            b.b_long,
            COUNT(l.loc_lat) as sum_beacon
        FROM tb_building b
        LEFT JOIN tb_beacon bc ON bc.b_id = b.b_id AND bc.bc_flag = '1'
        LEFT JOIN tb_location l ON l.bc_id = bc.bc_id AND l.updated_at >= '${start_date}' AND l.updated_at <= '${end_date}'
        WHERE b.b_flag = '1'
    `;

    if (b_id.toString().toUpperCase() !== "ALL") {
      script += ` AND b.b_id = '${b_id}'`;
    }
    
    script += ` GROUP BY b.b_id, b.b_name, b.b_lat, b.b_long ORDER BY b.b_id`;

    const result = await db.get(null, script, config);

    if (result.code) {
      throw new Error(result.message);
    }

    res.json(result.data);

  } catch (err) {
    console.error("Error in postCountBeaconForPlace:", err.message);
    res.status(500).json({ message: "Internal Server Error", error: err.message });
  }
};
