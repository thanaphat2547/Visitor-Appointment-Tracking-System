const db = require("../../libraty/pgConnection");
const moment = require('moment');
const express = require('express');
const turf = require("@turf/turf");
const config = require('../../configuration/connection');
const admin = require("../../libraty/firebase-admin");

const router = express.Router();

// ฟังก์ชัน สำหรับสร้าง log_id
async function generateNextLogId() {
  try {
    const result = await db.get(null, `SELECT nextval('notification_log_id_seq') AS "nextId"`, config);
    if (result && result.data && result.data.length > 0) {
      const nextId = result.data[0].nextId;
      return `N${String(nextId).padStart(6, '0')}`;
    }
    return `N${Date.now()}`;
  } catch (err) {
    return `N${Date.now()}`;
  }
}

// ฟังก์ชันคำนวณและอัปเดตอาคารที่ใกล้ที่สุด
async function updateBeaconBuilding(bc_id, lat, long) {
  try {
    const beaconPoint = turf.point([long, lat]);
    const buildingResult = await db.get(null, `SELECT b_id, b_name, b_lat, b_long, b_radius FROM tb_building WHERE b_flag = '1'`, config);

    let closestBuilding = null;
    let minDist = Infinity;

    for (const b of buildingResult.data) {
      const bPoint = turf.point([parseFloat(b.b_long), parseFloat(b.b_lat)]);
      const dist = turf.distance(beaconPoint, bPoint, { units: 'meters' });
      if (dist < minDist) {
        minDist = dist;
        closestBuilding = b;
      }
    }

    if (closestBuilding) {
      console.log(`📍 คำนวณอาคาร: ${closestBuilding.b_name} (${closestBuilding.b_id}) - ระยะ: ${Math.round(minDist)}m`);
      return { 
        b_id: closestBuilding.b_id, 
        b_name: closestBuilding.b_name,
        distance: Math.round(minDist),
        inside_radius: minDist <= closestBuilding.b_radius
      };
    }
    return null;
  } catch (error) {
    console.error('❌ Error in updateBeaconBuilding:', error);
    return null;
  }
}

// ฟังก์ชันหลักในการรับตำแหน่งจาก Beacon
exports.putLocationBeacon = async (req, res) => {
  const { bc_uuid, loc_lat, loc_long, status, vis_id } = req.body;
  const now = new Date();
  let current_bk_id = null;
  let current_b_id = null;

  console.log('📥 Request Beacon Event:', { bc_uuid, loc_lat, loc_long, status, vis_id });

  if (!bc_uuid || loc_lat === undefined || loc_long === undefined) {
    return res.status(400).json({ error: "Missing required fields" });
  }

  try {
    const checkbeacon = await db.get(null, `SELECT "bc_id", "bc_name" FROM tb_beacon WHERE "bc_uuid" = $1 AND "bc_flag" = '1'`, config, [bc_uuid]);
    if (!checkbeacon.data || checkbeacon.data.length === 0) {
      return res.status(404).json({ message: "ไม่พบ UUID beacon ในระบบ" });
    }

    const bc_id = checkbeacon.data[0].bc_id;

    if (status === "IN") {
      const buildingInfo = await updateBeaconBuilding(bc_id, loc_lat, loc_long);
      current_b_id = buildingInfo?.b_id; 

      if (current_b_id && vis_id) {
        const checkBookingScript = `
            SELECT b."bk_id", b."emp_id", v."vis_firstname" || ' ' || v."vis_lastname" as visitor_name
            FROM tb_booking b
            JOIN tb_visitor v ON b."vis_id" = v."vis_id"
            WHERE b."vis_id" = $1 AND b."b_id" = $2 AND b."bk_status" IN ('0', '3')
              AND NOW() >= (b."appointment_start" - INTERVAL '60 minutes')
              AND NOW() <= (b."appointment_end" + INTERVAL '60 minutes')
            LIMIT 1
        `;
        const bookingResult = await db.get(null, checkBookingScript, config, [vis_id, current_b_id]);

        if (bookingResult.data && bookingResult.data.length > 0) {
          const booking = bookingResult.data[0];
          current_bk_id = booking.bk_id;
          
          // ส่งแจ้งเตือน
          await sendCustomNotification(booking.emp_id, 'พนักงาน', 'ผู้มาติดต่อนัดหมายมาถึงแล้ว', `คุณ ${booking.visitor_name} มาถึง ${buildingInfo.b_name} แล้ว`, current_bk_id);
          await sendCustomNotification(vis_id, 'ผู้มาติดต่อ', 'เช็คอินนัดหมายสำเร็จ', `คุณมาถึง ${buildingInfo.b_name} เรียบร้อยแล้ว`, current_bk_id);

          await db.execute(null, `UPDATE tb_booking SET "bk_status" = '1', "bk_checkin" = NOW() WHERE "bk_id" = $1`, config, [current_bk_id]);
        }
      }

      // บันทึกตำแหน่งล่าสุด
      const existingIn = await db.get(null, `SELECT "bc_id" FROM tb_location WHERE "bc_id" = $1 AND "lobc_time_out" IS NULL`, config, [bc_id]);
      if (existingIn.data && existingIn.data.length > 0) {
        await db.execute(null, 
          `UPDATE tb_location SET "b_id" = $1, "loc_lat" = $2, "loc_long" = $3, "lobc_time_in" = $4, "vis_id" = $5, "bk_id" = $6 WHERE "bc_id" = $7 AND "lobc_time_out" IS NULL`, 
          config, [current_b_id, loc_lat, loc_long, now, vis_id, current_bk_id, bc_id]);
      } else {
        await db.execute(null, 
          `INSERT INTO tb_location ("bc_id", "b_id", "loc_lat", "loc_long", "lobc_time_in", "vis_id", "bk_id") VALUES ($1, $2, $3, $4, $5, $6, $7)`, 
          config, [bc_id, current_b_id, loc_lat, loc_long, now, vis_id, current_bk_id]);
      }

    } else if (status === "OUT") {
      // ดึงข้อมูลพิกัดปัจจุบันและเวลาสิ้นสุดนัดหมายมาเช็ค
      const locData = await db.get(null, `
        SELECT l.*, b.appointment_end 
        FROM tb_location l
        LEFT JOIN tb_booking b ON l.bk_id = b.bk_id
        WHERE l.bc_id = $1 AND l.lobc_time_out IS NULL
      `, config, [bc_id]);

      if (locData.data && locData.data.length > 0) {
        const record = locData.data[0];
        
        // คำนวณเวลา: เวลานัดเลิก + 30 นาที
        const gracePeriodEnd = moment(record.appointment_end).add(30, 'minutes');
        const isTimeUp = moment().isAfter(gracePeriodEnd);

        console.log(`📡 Checking OUT for Beacon: ${bc_id}`);
        console.log(`⏰ Appointment End (+30m): ${gracePeriodEnd.format('HH:mm:ss')}`);

        // ถ้าเลยเวลานัดมาแล้ว 30 นาที ให้ย้ายไป history และลบออกจาก location
        if (isTimeUp) {
          console.log(`✅ Time is up! Moving data to history and deleting from location.`);

          // บันทึกลง history
          const historyScript = `
            INSERT INTO tb_beacon_history (
              "bc_id", 
              "vis_id", 
              "bk_id", 
              "loc_lat", 
              "loc_long", 
              "hi_time_in", 
              "hi_time_out", 
              "hi_date"
            )
            VALUES ($1, $2, $3, $4, $5, $6, NOW(), CURRENT_DATE)
          `;
          
          await db.execute(null, historyScript, config, [
            record.bc_id, 
            record.vis_id, 
            record.bk_id, 
            record.loc_lat, 
            record.loc_long, 
            record.lobc_time_in // ดึงค่าเวลาเข้าจากตาราง location มาใส่ hi_time_in
          ]);

          // อัปเดตสถานะนัดหมายใน tb_booking เป็น 'เสร็จสิ้น'
          if (record.bk_id) {
            await db.execute(null, `UPDATE tb_booking SET "bk_status" = '2', "bk_checkout" = NOW() WHERE "bk_id" = $1`, config, [record.bk_id]);
          }

          // ลบออกจาก tb_location เพื่อให้หมุดหายไป
          await db.execute(null, `DELETE FROM tb_location WHERE "bc_id" = $1`, config, [bc_id]);
          
        } else {
          // ถ้ายังไม่ถึงเวลา ปล่อยให้ข้อมูลอยู่ใน tb_location ต่อไป หมุดจะไม่หายจากแผนที่
          console.log(`⏳ Still in appointment period. Keeping marker on map.`);
        }
      }
    }

    return res.json({ status: "success", message: `บันทึกข้อมูล ${status} เรียบร้อย`, vis_id: vis_id });

  } catch (err) {
    console.error("❌ Error:", err);
    return res.status(500).json({ error: "Internal Server Error" });
  }
};

async function sendCustomNotification(targetId, userType, title, body, bk_id = null) {
  try {
    console.log(`🔔 Attempting to send notification to: ${targetId} (${userType})`);
    
    const log_id = await generateNextLogId();
    await db.execute(null, `
        INSERT INTO tb_notification ("log_id", "bk_id", "user_id", "user_type", "title", "body", "eventtype", "created_at")
        VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
    `, config, [log_id, bk_id, targetId, userType, title, body, 'IN']);

    let token = null;
    if (userType === 'พนักงาน') {
      const userRes = await db.get(null, `SELECT "emp_fcm_token" FROM public."tb_employee" WHERE "emp_id" = $1`, config, [targetId]);
      token = userRes.data[0]?.emp_fcm_token;
    } else if (userType === 'ผู้มาติดต่อ') {
      const visRes = await db.get(null, `SELECT "vis_fcm_token" FROM public."tb_visitor" WHERE "vis_id" = $1`, config, [targetId]);
      token = visRes.data[0]?.vis_fcm_token;
    }

    if (token) {
      const message = {
        token: token,
        notification: { title, body },
        data: { 
          log_id, 
          title, 
          body,
          targetUserId: String(targetId),
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        },
        android: {
          priority: 'high',
          notification: {
            channel_id: 'high_importance_channel',
            priority: 'max'
          }
        }
      };
      await admin.messaging().send(message);
      console.log(`🚀 FCM Push Sent Successfully to ${targetId}`);
    } else {
      console.log(`⚠️ Skip Push: No token found for user ${targetId}`);
    }
  } catch (err) {
    console.error("❌ Notification function failed:", err);
  }
}

// ดึงตำแหน่ง Beacon ทั้งหมดสำหรับหน้า Map
exports.getLocationBeacons = async (req, res) => {
  try {
    let script = `
      SELECT 
        lb."bc_id", 
        lb."loc_lat", 
        lb."loc_long", 
        lb."lobc_time_in", 
        lb."lobc_time_out", 
        b."bc_name", 
        bu."b_name" as building_name, 
        lb."vis_id", 
        v."vis_firstname" || ' ' || v."vis_lastname" as visitor_name,
        v."vis_phone" as visitor_contact,
        lb."bk_id",
        CASE WHEN lb."lobc_time_out" IS NULL THEN 'IN' ELSE 'OUT' END as status
      FROM public."tb_location" lb 
      INNER JOIN public."tb_beacon" b ON lb."bc_id" = b."bc_id" 
      LEFT JOIN public."tb_building" bu ON lb."b_id" = bu."b_id" 
      LEFT JOIN public."tb_visitor" v ON lb."vis_id" = v."vis_id"
      WHERE b."bc_flag" = '1' 
    `;
    const result = await db.get(null, script, config);
    res.json({ status: 'success', data: result.data || [] });
  } catch (err) { 
    console.error("❌ Error in getLocationBeacons:", err);
    res.status(500).json({ error: 'Failed to fetch location beacons' }); 
  }
};

exports.Calculate = async (req, res) => {
  try {
    const { bc_uuid, lat, long } = req.body;
    const beaconResult = await db.get(null, `SELECT "bc_id" FROM tb_beacon WHERE "bc_uuid" = $1 AND "bc_flag" = '1'`, config, [bc_uuid]);
    if (!beaconResult.data?.[0]) return res.status(404).json({ error: "Beacon not found" });
    const buildingInfo = await updateBeaconBuilding(beaconResult.data[0].bc_id, lat, long);
    res.json({ data: buildingInfo });
  } catch (e) { res.status(500).json({ error: e.message }); }
}

module.exports = {
  router,
  putLocationBeacon: exports.putLocationBeacon,
  getLocationBeacons: exports.getLocationBeacons,
  Calculate: exports.Calculate,
};