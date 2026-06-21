const admin = require("firebase-admin");
const serviceAccount = require("../configuration/visitor-tracking-24eac-firebase-adminsdk-fbsvc-d181b95f45.json");

if (!admin.apps.length) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log("✅ Firebase Admin Connected Successfully!");
  } catch (error) {
    console.error("❌ Firebase Init Error:", error);
  }
}
module.exports = admin;