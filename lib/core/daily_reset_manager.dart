import 'package:shared_preferences/shared_preferences.dart';

Future<void> checkAndResetDailyStats() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  DateTime now = DateTime.now();
  DateTime virtualToday = now.subtract(const Duration(hours: 3));
  String? lastResetString = prefs.getString('lastResetDate');

  bool needsReset = false;
  if (lastResetString == null) {
    needsReset = true;
  } else {
    DateTime lastResetDate = DateTime.parse(lastResetString);
    if (virtualToday.day != lastResetDate.day ||
        virtualToday.month != lastResetDate.month ||
        virtualToday.year != lastResetDate.year) {
      needsReset = true;
    }
  }
  if (needsReset) {
    await prefs.setInt('waterCount', 0);
    await prefs.setInt('dailySteps', 0);
    await prefs.setInt('vahaLevel', 0);
    await prefs.setString('lastResetDate', virtualToday.toIso8601String());
    
    print("Gece 3 Sıfırlaması Başarıyla Yapıldı! Tertemiz bir gün.");
  }
}