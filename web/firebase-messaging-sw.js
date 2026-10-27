importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing in
// your app's Firebase config. For Firebase JS SDK v7.20.0 and later, `measurementId` is optional
firebase.initializeApp({
  apiKey: 'AIzaSyBiHv-mJu5VQnJ-lhkHzP41FDYbzkp7nuU',
  authDomain: 'petguardian-0000.firebaseapp.com',
  projectId: 'petguardian-0000',
  storageBucket: 'petguardian-0000.appspot.com',
  messagingSenderId: '274043292034',
  appId: '1:274043292034:web:68e4274b00bce183a4679b'
});

const messaging = firebase.messaging();

// Background message handler
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || 'PetGuardian';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
