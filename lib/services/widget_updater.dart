import 'package:home_widget/home_widget.dart';

class WidgetUpdater {
  static const String _widgetName = 'NowPlayingWidget';

  static Future<void> updateNowPlaying({
    required String? title,
    required String? artist,
    required bool isPlaying,
    required int? albumId,
  }) async {
    await HomeWidget.saveWidgetData('title', title ?? 'No track');
    await HomeWidget.saveWidgetData('artist', artist ?? 'Not playing');
    await HomeWidget.saveWidgetData('isPlaying', isPlaying);
    await HomeWidget.updateWidget(androidName: _widgetName);
  }

  static Future<void> clearNowPlaying() async {
    await HomeWidget.saveWidgetData('title', 'No track');
    await HomeWidget.saveWidgetData('artist', 'Not playing');
    await HomeWidget.saveWidgetData('isPlaying', false);
    await HomeWidget.updateWidget(androidName: _widgetName);
  }
}
