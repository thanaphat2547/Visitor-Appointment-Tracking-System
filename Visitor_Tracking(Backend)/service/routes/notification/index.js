const express = require('express');
const router = express.Router();
const notificationController = require('../../controllers/notificationController');

// ดึงประวัติการเก็บข้อมูลทั้งหมด
router.get('/history', notificationController.getHistory);

// บันทึก FCM token สำหรับ push notification
router.post('/save-fcm-token', notificationController.saveFcmToken);

// เรียกทดสอบการส่งแจ้งเตือนล่วงหน้า 1 วัน
router.post('/send-1day-reminders', notificationController.send1DayReminders);

// ล้างการแจ้งเตือนของผู้ใช้คนเดียว
router.post('/clear', notificationController.clearNotificationHistory)

module.exports = router;
