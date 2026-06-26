import 'package:shared_preferences/shared_preferences.dart';
import 'package:cadence/core/constants/app_constants.dart';

class DateService {
  DateService._();

  // Returns today's ISO date string, protected against clock manipulation.
  // If the system clock appears to have moved backward, returns the last
  // known date to protect streak and stat integrity.
  static Future<String> getSafeToday() async {
    final prefs = await SharedPreferences.getInstance();
    final todayReal = _isoDate(DateTime.now());
    final lastKnown = prefs.getString(AppConstants.keyLastKnownDate);

    if (lastKnown != null && todayReal.compareTo(lastKnown) < 0) {
      return lastKnown;
    }

    await prefs.setString(AppConstants.keyLastKnownDate, todayReal);
    return todayReal;
  }

  static String _isoDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '-${dt.month.toString().padLeft(2, '0')}'
        '-${dt.day.toString().padLeft(2, '0')}';
  }

  static String isoToday() => _isoDate(DateTime.now());

  static int daysSince(DateTime past) {
    final now = DateTime.now();
    // Drift returns DateTimes as UTC (isUtc: true). Convert to local before
    // extracting year/month/day so we compare calendar dates in the user's
    // timezone, not UTC. Then use UTC midnight for the subtraction so DST
    // transitions (which shorten/lengthen a local day) don't corrupt the count.
    final todayUTC = DateTime.utc(now.year, now.month, now.day);
    final pastLocal = past.toLocal();
    final pastUTC = DateTime.utc(pastLocal.year, pastLocal.month, pastLocal.day);
    return todayUTC.difference(pastUTC).inDays;
  }
}
