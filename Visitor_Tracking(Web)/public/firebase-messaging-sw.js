importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: "AIzaSyC-wVVkYfTAzbObXUNd_ZVU0IiGhXhh2L0",
  authDomain: "visitor-tracking-24eac.firebaseapp.com",
  projectId: "visitor-tracking-24eac",
  storageBucket: "visitor-tracking-24eac.firebasestorage.app",
  messagingSenderId: "569613070983",
  appId: "1:569613070983:web:5b3822f691d782ade73e22"
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();


messaging.onBackgroundMessage((payload) => {
  console.log('[SW] Background Message:', payload);


  const notificationTitle = payload.notification?.title || payload.data?.title || 'แจ้งเตือนนัดหมาย';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || 'มีข้อมูลใหม่ในระบบ',
    icon: '/โลโก้.png', 
    data: payload.data,  
    badge: '/โลโก้.png'  
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification clicked:', event.notification);
  event.notification.close(); 


  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url === '/' && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});