const express = require("express");
const cors = require("cors");
const cron = require('node-cron');
const app = express();
const HOST = "0.0.0.0";
const port = 3001;
const BOOKING_CONTROLLER = require('./routes/booking/booking');
const NOTIFICATION_CONTROLLER = require('./controllers/notificationController');
const BOOKING_CRON_SCHEDULE = '* * * * *'; // every minute

// Allow all origins for development (mobile + web from any IP)
app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (mobile apps, Postman, etc.)
    if (!origin) return callback(null, true);
    // Allow any localhost or 10.212.22.x origin
    const allowed = [
      /^http:\/\/localhost(:\d+)?$/,
      /^http:\/\/127\.0\.0\.1(:\d+)?$/,
      /^http:\/\/10\.212\.22\.\d+(:\d+)?$/,
    ];
    if (allowed.some(pattern => pattern.test(origin))) {
      return callback(null, true);
    }
    return callback(null, true); // Allow all for now (dev mode)
  },
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
  credentials: true
}));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

//เรียกใช้งาน Routes
const beacon = require("./routes/beacon");
const booking = require("./routes/booking");
const building = require("./routes/building");
const employee = require("./routes/employee");
const location_beacon = require("./routes/location_beacon");
const report = require("./routes/report")
const visitor = require("./routes/visitor")
const checkbeacon = require("./routes/check_beacon");
const notificationRoutes = require('./routes/notification');

//กำหนด Path สำหรับ API
app.get("/", (req, res) => {
  res.send("Visitor Tracking API - Online ✅");
});

app.use("/beacon", beacon);
app.use("/booking", booking);
app.use("/building", building);
app.use("/employee", employee);
app.use("/location_beacon", location_beacon);
app.use("/report", report);
app.use("/visitor", visitor);
app.use("/checkbeacon", checkbeacon);
app.use('/notification', notificationRoutes);

// อัปเดตสถานะการนัดหมายตามกำหนดเวลาทุกนาที
cron.schedule(BOOKING_CRON_SCHEDULE, async () => {
  console.log('--- Running Auto Update Booking Statuses ---');
  try {
    await BOOKING_CONTROLLER.updateBookingStatuses();
    console.log('✅ Booking status cron job completed');
  } catch (error) {
    console.error('❌ Booking status cron error:', error);
  }
});

// ตั้งค่าการแจ้งเตือนล่วงหน้า 1 วัน ทุก 30 นาที
cron.schedule('*/30 * * * *', async () => {
  console.log('--- Running 1-Day Reminder Service ---');
  try {
    await NOTIFICATION_CONTROLLER.send1DayReminders();
    console.log('✅ 1-day reminder cron job completed');
  } catch (error) {
    console.error('❌ 1-day reminder cron error:', error);
  }
});

app.listen(port, HOST, () => {
  console.log(`✅ Server running on http://192.168.1.33:${port}`);
});