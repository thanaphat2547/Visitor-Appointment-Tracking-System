const admin = require('../../config/firebase');
const serviceAccount = require('../config/firebase-key.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

async function sendNotification(fcmToken, title, body, data = {}) {
  const message = {
    notification: {
      title: title,
      body: body
    },
    data: data,
    token: fcmToken
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('✅ Notification sent successfully:', response);
    return { success: true, messageId: response };
  } catch (error) {
    console.error('❌ Error sending notification:', error);
    return { success: false, error: error.message };
  }
}

async function sendMulticastNotification(fcmTokens, title, body, data = {}) {
  const message = {
    notification: {
      title: title,
      body: body
    },
    data: data,
    tokens: fcmTokens
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`✅ ${response.successCount} notifications sent successfully`);
    console.log(`❌ ${response.failureCount} notifications failed`);
    return { 
      success: true, 
      successCount: response.successCount,
      failureCount: response.failureCount,
      responses: response.responses 
    };
  } catch (error) {
    console.error('❌ Error sending multicast notification:', error);
    return { success: false, error: error.message };
  }
}

module.exports = {
  sendNotification,
  sendMulticastNotification
};