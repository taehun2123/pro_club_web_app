/* eslint-disable max-len */
// functions/index.js
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getMessaging} = require("firebase-admin/messaging");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

initializeApp();

const functionOptions = {
  region: "asia-northeast3", // 리전 설정 (도쿄)
  memory: "256MiB", // 메모리 설정 (기본값)
  timeoutSeconds: 60, // 타임아웃 설정 (기본값)
};
// 새 공지사항이 생성될 때 알림 전송
exports.sendNoticeNotification = onDocumentCreated("notices/{noticeId}", functionOptions, async (event) => {
  const snapshot = event.data;
  const context = event.params;

  if (!snapshot) {
    console.log("No data associated with the event");
    return null;
  }

  const noticeData = snapshot.data();
  // 공지사항 내용
  const title = "새 공지사항";
  const body = noticeData.title;
  // 모든 사용자에게 알림 (토픽 방식)
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      noticeId: context.noticeId,
      type: "notice",
      url: `/notice/${context.noticeId}`,
    },
    topic: "all_notices",
  };

  try {
    const response = await getMessaging().send(message);
    console.log("공지사항 알림 전송 성공:", response);
    return {success: true};
  } catch (error) {
    console.error("공지사항 알림 전송 오류:", error);
    return {error: error.code};
  }
});

// 멘션 알림 전송
exports.sendMentionNotification = onDocumentCreated("notifications/{notificationId}", async (event) => {
  const snapshot = event.data;
  const context = event.params;

  if (!snapshot) {
    console.log("No data associated with the event");
    return null;
  }

  const notification = snapshot.data();
  // 멘션 알림만 처리
  if (notification.type !== "mention") {
    return null;
  }

  const userId = notification.userId;
  try {
    // 사용자 FCM 토큰 가져오기
    const userDoc = await getFirestore().collection("users").doc(userId).get();

    if (!userDoc.exists) {
      console.log("사용자를 찾을 수 없음:", userId);
      return null;
    }

    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) {
      console.log("FCM 토큰 없음:", userId);
      return null;
    }

    // URL 생성 (댓글 또는 게시글)
    const url = `/post/${notification.sourceId}`;

    // 알림 메시지 구성
    const message = {
      notification: {
        title: notification.title,
        body: notification.content,
      },
      data: {
        notificationId: context.notificationId,
        sourceId: notification.sourceId || "",
        type: "mention",
        url: url,
      },
      tokens: fcmTokens,
    };

    // FCM 메시지 전송
    const response = await getMessaging().sendEachForMulticast(message);
    console.log(`${fcmTokens.length}개 기기 중 ${response.successCount}개 전송 성공`);

    // 실패한 토큰 제거
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(fcmTokens[idx]);
        }
      });

      if (failedTokens.length > 0) {
        await getFirestore().collection("users").doc(userId).update({
          fcmTokens: FieldValue.arrayRemove(...failedTokens),
        });
      }
    }

    return {success: true, successCount: response.successCount};
  } catch (error) {
    console.error("멘션 알림 전송 오류:", error);
    return {error: error.code};
  }
},
);
