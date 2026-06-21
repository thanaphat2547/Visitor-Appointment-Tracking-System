import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
import { getAuth } from "firebase/auth";
import { getDatabase } from "firebase/database";
import { getMessaging, onMessage, getToken } from "firebase/messaging"; 
import emitter from "@/eventBus";


const firebaseConfig = {
  apiKey: "AIzaSyC-wVVkYfTAzbObXUNd_ZVU0IiGhXhh2L0",
  authDomain: "visitor-tracking-24eac.firebaseapp.com",
  projectId: "visitor-tracking-24eac",
  storageBucket: "visitor-tracking-24eac.firebasestorage.app",
  messagingSenderId: "569613070983",
  appId: "1:569613070983:web:5b3822f691d782ade73e22",
  measurementId: "G-9F6P5PN4FH"
};


const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);
const auth = getAuth(app);
const db = getDatabase(app);
const messaging = getMessaging(app); 


onMessage(messaging, (payload) => {
  console.log('📩 Received FCM notification:', payload);
  
  const { data } = payload;


  if (!data) {
    console.error('❌ No data in FCM payload!');
    return;
  }

  if (!data.log_id || !data.user_id) {
    console.error('❌ Data incomplete (log_id or user_id is missing)!', data);
    return;
  }

  const currentUserId = localStorage.getItem('user_id');
  console.log('👤 Current user:', currentUserId, '| FCM target user:', data.user_id);

  if (data.user_id && data.user_id !== currentUserId) {
    console.log('⚠️ FCM for different user, ignoring.');
    return;
  }

  const notificationData = {
    log_id: data.log_id,
    user_id: data.user_id,
    title: data.title || 'ไม่มีหัวข้อ',
    body: data.body || 'ไม่มีเนื้อหา',
    eventtype: data.eventtype || 'UNKNOWN',
    bc_id: data.bc_id || '',
    b_id: data.b_id || '',
    timestamp: data.timestamp || new Date().toISOString(),
    created_at: data.timestamp || new Date().toISOString()
  };

  console.log('📤 Emitting to UI:', notificationData);

  emitter.emit('new-notification', notificationData);
});

export { app, analytics, auth, db, messaging, onMessage, getToken };