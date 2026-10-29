package com.HaizStudio.FirebaseCloudMessaging;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;

import com.HaizStudio.ChakaZulu.R;
import com.HaizStudio.ChakaZulu.Starting;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

/**
 * Push notifications sent from the Firebase console.
 * <p>
 * When the game is in the background Firebase shows them by itself; this class
 * shows the ones that arrive while the game is open.
 */
public class MyFirebaseMessagingService extends FirebaseMessagingService {

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        RemoteMessage.Notification notification = remoteMessage.getNotification();
        if (notification != null)
            showNotification(notification.getTitle(), notification.getBody());
    }

    private void showNotification(String title, String body) {
        Intent intent = new Intent(this, Starting.class)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, intent,
                PendingIntent.FLAG_ONE_SHOT | PendingIntent.FLAG_IMMUTABLE);

        String channelId = getString(R.string.default_notification_channel_id);
        NotificationManager notificationManager = getSystemService(NotificationManager.class);
        notificationManager.createNotificationChannel(new NotificationChannel(channelId,
                getString(R.string.notification_channel_name), NotificationManager.IMPORTANCE_DEFAULT));

        Notification notification = new Notification.Builder(this, channelId)
                .setSmallIcon(R.drawable.icon_notification)
                .setContentTitle(title != null ? title : getString(R.string.app_name))
                .setContentText(body)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build();
        notificationManager.notify(0, notification);
    }
}
