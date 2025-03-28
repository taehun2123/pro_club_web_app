// /web/firebase-messaging-sw.js
// 이 파일은 반드시 웹 애플리케이션의 루트 디렉토리에 있어야 합니다!

// Firebase SDK 가져오기 (호환성 버전 사용)
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js');

// 서비스 워커 활성화 이벤트 콘솔 출력 (디버깅용)
self.addEventListener('activate', event => {
  console.log('Firebase Messaging 서비스 워커가 활성화되었습니다!');
});

// 문제 해결: 하나의 일관된 초기화 흐름 사용
// Firebase Hosting의 init.json에서 구성 가져오기
fetch('/__/firebase/init.json')
  .then(response => {
    if (!response.ok) {
      throw new Error('Firebase 초기화 구성을 불러올 수 없습니다. 상태 코드: ' + response.status);
    }
    return response.json();
  })
  .then(firebaseConfig => {
    // 초기화 설정 로깅 (디버깅용, 실제 환경에서는 제거)
    console.log('Firebase 구성을 불러왔습니다.');
    
    // Firebase 앱 초기화
    firebase.initializeApp(firebaseConfig);
    
    // 초기화 후 messaging 객체 생성
    const messaging = firebase.messaging();
    
    // 백그라운드 메시지 처리
    messaging.onBackgroundMessage(function(payload) {
      console.log('백그라운드 메시지 수신:', payload);
      
      // 알림 표시
      const notificationTitle = payload.notification?.title || '새 알림';
      const notificationOptions = {
        body: payload.notification?.body || '',
        icon: '/icons/app_icon.png',  // 앱 아이콘 경로 (웹 루트 기준)
        data: payload.data
      };
      
      return self.registration.showNotification(notificationTitle, notificationOptions);
    });
    
    console.log('Firebase Messaging이 성공적으로 초기화되었습니다.');
  })
  .catch(error => {
    console.error('Firebase 초기화 실패:', error);
  
  });

// 알림 클릭 처리
self.addEventListener('notificationclick', function(event) {
  console.log('알림 클릭됨:', event);
  
  event.notification.close();
  
  // 클릭 시 열 URL (data에 url이 있으면 사용, 없으면 기본값)
  const urlToOpen = event.notification.data?.url || '/';
  
  event.waitUntil(
    clients.matchAll({type: 'window'}).then(function(clientList) {
      // 이미 열린 탭이 있는지 확인
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if (client.url.includes(urlToOpen) && 'focus' in client) {
          return client.focus();
        }
      }
      // 열린 탭이 없으면 새 탭 열기
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});