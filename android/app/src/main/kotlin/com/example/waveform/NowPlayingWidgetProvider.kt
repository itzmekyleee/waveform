package com.example.waveform

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class NowPlayingWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.now_playing_widget).apply {
            val openIntent =
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_container, openIntent)

            val title = widgetData.getString("title", "No track")
            setTextViewText(R.id.widget_title, title ?: "No track")

            val artist = widgetData.getString("artist", "Not playing")
            setTextViewText(R.id.widget_artist, artist ?: "Not playing")

            val isPlaying = widgetData.getBoolean("isPlaying", false)
            if (isPlaying) {
              setImageViewResource(R.id.widget_play_pause, android.R.drawable.ic_media_pause)
            } else {
              setImageViewResource(R.id.widget_play_pause, android.R.drawable.ic_media_play)
            }
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
