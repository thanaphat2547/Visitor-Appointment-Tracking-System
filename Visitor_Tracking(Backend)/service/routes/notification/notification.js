const moment = require('moment');
const db = require("../../libraty/pgConnection");
const config = require('../../configuration/connection');
const admin = require("../../libraty/firebase-admin");

const sendPush = async (token, title, body, data = {}) => {
  if (!token) return;
  const message = {
    notification: { title, body },
    data: data,
    android: {
      notification: {
        sound: "default",
        clickAction: "FLUTTER_NOTIFICATION_CLICK"
      }
    },
    token: token
  };

  try {
    const response = await admin.messaging().send(message);
    console.log("🚀 Banner Notification Sent Successfully:", response);
  } catch (error) {
    console.error("❌ Firebase Push Error:", error);
  }
};

async function logNotification(logId, bkId, userId, userType, title, body, eventtype) {
  await db.execute(null, `
      INSERT INTO public."tb_notification" ("log_id", "bk_id", "user_id", "user_type", "title", "body", "eventtype", "created_at")
      VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
  `, config, [logId, bkId, userId, userType, title, body, eventtype]);
}

async function hasReminderBeenSent(bkId, userId, eventtype) {
  const result = await db.get(null, `
      SELECT 1 FROM public."tb_notification"
      WHERE "bk_id" = $1 AND "user_id" = $2 AND "eventtype" = $3
      LIMIT 1
  `, config, [bkId, userId, eventtype]);
  return result.data && result.data.length > 0;
}

async function send1DayReminders(req, res) {
  try {
    console.log('🔔 Checking for 1-day before appointment reminders...');
    const upcomingScript = `
      SELECT b."bk_id", b."appointment_start",
             v."vis_id", v."vis_firstname", v."vis_lastname", v."vis_fcm_token",
             e."emp_id", e."emp_firstname", e."emp_lastname", e."emp_fcm_token"
      FROM public."tb_booking" b
      JOIN public."tb_visitor" v ON b."vis_id" = v."vis_id"
      JOIN public."tb_employee" e ON b."emp_id" = e."emp_id"
      WHERE b."bk_status" = '0'
        AND b."appointment_start" BETWEEN NOW() + INTERVAL '23 hours 55 minutes' AND NOW() + INTERVAL '1 day 5 minutes'
    `;
    const result = await db.get(null, upcomingScript, config);
    const bookings = result.data || [];

    for (const booking of bookings) {
      const startTime = moment(booking.appointment_start).format('YYYY-MM-DD HH:mm');
      const visitorName = `${booking.vis_firstname || ''} ${booking.vis_lastname || ''}`.trim();
      const bookingTitleVisitor = 'เตือนนัดหมายล่วงหน้า 1 วัน';
      const bookingBodyVisitor = `คุณมีนัดหมายพรุ่งนี้เวลา ${startTime}`;
      const bookingTitleOfficer = 'แจ้งเตือน: มีผู้มาติดต่อพรุ่งนี้';
      const bookingBodyOfficer = `คุณ ${visitorName} มีนัดหมายพรุ่งนี้เวลา ${startTime}`;

      const visitorReminderSent = await hasReminderBeenSent(booking.bk_id, booking.vis_id, 'REMINDER_1DAY_VISITOR');
      if (!visitorReminderSent && booking.vis_fcm_token) {
        await sendPush(booking.vis_fcm_token, bookingTitleVisitor, bookingBodyVisitor, { bk_id: booking.bk_id });
        const logId = `N${Date.now()}V${booking.vis_id}`;
        await logNotification(logId, booking.bk_id, booking.vis_id, 'ผู้มาติดต่อ', bookingTitleVisitor, bookingBodyVisitor, 'REMINDER_1DAY_VISITOR');
        console.log(`✅ Reminder sent to visitor ${booking.vis_id} for booking ${booking.bk_id}`);
      }

      const officerReminderSent = await hasReminderBeenSent(booking.bk_id, booking.emp_id, 'REMINDER_1DAY_OFFICER');
      if (!officerReminderSent && booking.emp_fcm_token) {
        await sendPush(booking.emp_fcm_token, bookingTitleOfficer, bookingBodyOfficer, { bk_id: booking.bk_id });
        const logId = `N${Date.now()}E${booking.emp_id}`;
        await logNotification(logId, booking.bk_id, booking.emp_id, 'พนักงาน', bookingTitleOfficer, bookingBodyOfficer, 'REMINDER_1DAY_OFFICER');
        console.log(`✅ Reminder sent to officer ${booking.emp_id} for booking ${booking.bk_id}`);
      }
    }

    if (res) {
      return res.json({ success: true, message: '1-day reminder check completed', totalBookings: bookings.length });
    }
  } catch (error) {
    console.error('❌ Error sending 1-day reminders:', error);
    if (res) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }
}

exports.send1DayReminders = send1DayReminders;

// ดึงประวัติการแจ้งเตือน
exports.getHistory = async (req, res) => {
  try {
    const { user_id, title, eventtype } = req.query;

    let query = `
      SELECT 
        log_id,
        user_id,
        title,
        body,
        eventtype,
        bk_id,
        user_type,
        created_at
      FROM public."tb_notification"
      WHERE 1=1
    `;

    const params = [];
    let paramIndex = 1;

    if (user_id) {
      query += ` AND "user_id" = $${paramIndex++}`;
      params.push(user_id);
    }

    if (title) {
      query += ` AND title LIKE $${paramIndex++}`;
      params.push(`%${title}%`);
    }

    if (eventtype) {
      query += ` AND eventtype = $${paramIndex++}`;
      params.push(eventtype);
    }

    query += ` ORDER BY created_at DESC LIMIT 50`;

    const result = await db.get(null, query, config, params);

    res.json({ success: true, notifications: result.data || [] });
  } catch (error) {
    console.error('Error in getHistory:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// บันทึก/อัปเดต FCM Token (พนักงาน หรือ ผู้มาติดต่อ)
exports.saveFcmToken = async (req, res) => {
  try {
    const { user_id, fcm_token, role } = req.body; 

    if (!user_id || !fcm_token || !role) {
      return res.status(400).json({ 
        success: false, 
        message: 'กรุณาระบุข้อมูลให้ครบ (user_id, fcm_token, role)' 
      });
    }

    let tableName = "";
    let idColumn = "";
    let tokenColumn = "";

    if (role === 'officer') {
      tableName = 'tb_employee';
      idColumn = 'emp_id';
      tokenColumn = 'emp_fcm_token'; 
    } else if (role === 'visitor') {
      tableName = 'tb_visitor';
      idColumn = 'vis_id';
      tokenColumn = 'vis_fcm_token'; 
    } else {
      return res.status(400).json({ success: false, message: 'Role ไม่ถูกต้อง' });
    }

    // ล้าง Token เก่าออกจากระบบก่อนเพื่อกันการส่งซ้ำซ้อน
    await db.execute(null, `UPDATE public."tb_employee" SET emp_fcm_token = NULL WHERE emp_fcm_token = $1`, config, [fcm_token]);
    await db.execute(null, `UPDATE public."tb_visitor" SET vis_fcm_token = NULL WHERE vis_fcm_token = $1`, config, [fcm_token]);

    // อัปเดต Token ใหม่ให้ User ปัจจุบัน
    const updateTokenScript = `
      UPDATE public."${tableName}" 
      SET ${tokenColumn} = $1 
      WHERE ${idColumn} = $2
    `;
    
    await db.execute(null, updateTokenScript, config, [fcm_token, user_id]);

    console.log(`✅ FCM token assigned to ${role}: '${user_id}'`);
    res.json({ success: true, message: `บันทึก FCM token สำหรับ ${role} สำเร็จ` });

  } catch (error) {
    console.error('Error in saveFcmToken:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// ล้างการแจ้งเตือนของผู้ใช้
exports.clearNotificationHistory = async (req, res) => {
  try {
    const { user_id } = req.body;
    if (!user_id) {
      return res.status(400).json({ success: false, message: 'กรุณาระบุ user_id' });
    }

    const deleteScript = `
      DELETE FROM public."tb_notification"
      WHERE user_id = $1
    `;
    await db.execute(null, deleteScript, config, [user_id]);

    res.json({ success: true, message: 'ล้างประวัติแจ้งเตือนเรียบร้อยแล้ว' });
  } catch (error) {
    console.error('Error in clearNotificationHistory:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

exports.sendPush = sendPush;