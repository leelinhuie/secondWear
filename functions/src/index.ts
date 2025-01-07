/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

// Define the notification data type
interface NotificationData {
  to: string;
  notification: {
    title: string;
    body: string;
  };
  data?: {
    [key: string]: string;
  };
}

exports.sendNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    try {
      const notification = event.data?.data() as NotificationData;

      if (!notification?.to) {
        console.error("No FCM token provided");
        return null;
      }

      const message: admin.messaging.Message = {
        token: notification.to,
        notification: {
          title: notification.notification.title,
          body: notification.notification.body,
        },
        data: notification.data || {},
        android: {
          priority: "high",
          notification: {
            channelId: "orders",
            priority: "high",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      // Send the notification
      const response = await admin.messaging().send(message);
      console.log("Successfully sent notification:", response);

      // Optionally, delete the notification document
      await event.data?.ref.delete();

      return response;
    } catch (error) {
      console.error("Error sending notification:", error);
      return null;
    }
  }
);
