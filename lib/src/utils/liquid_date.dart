import "../engine/liquid_options.dart";

class TimeZoneInfo {
  final int offsetMinutes; // JS-style: UTC - local
  final String? nameForZ; // for %Z

  TimeZoneInfo({required this.offsetMinutes, required this.nameForZ});
}

class LiquidDate {
  static DateTime? parseToInstant(Object? input) {
    if (input == null) return null;

    if (input is DateTime) {
      return input.isUtc ? input : input.toUtc();
    }

    if (input is num) {
      final n = input.toInt();
      final abs = n.abs();
      final ms = abs >= 1000000000000 ? n : n * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }

    final s = input.toString().trim();
    if (s.isEmpty) return null;

    final lower = s.toLowerCase();
    if (lower == "now" || lower == "today") {
      return DateTime.now().toUtc();
    }

    final iso = DateTime.tryParse(s);
    if (iso != null) return iso.isUtc ? iso : iso.toUtc();

    final ymdSlash = RegExp(
      r"^(\d{4})/(\d{1,2})/(\d{1,2})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$",
    );
    final m1 = ymdSlash.firstMatch(s);
    if (m1 != null) {
      final y = int.parse(m1.group(1)!);
      final mo = int.parse(m1.group(2)!);
      final d = int.parse(m1.group(3)!);
      final hh = m1.group(4) != null ? int.parse(m1.group(4)!) : 0;
      final mm = m1.group(5) != null ? int.parse(m1.group(5)!) : 0;
      final ss = m1.group(6) != null ? int.parse(m1.group(6)!) : 0;
      final local = DateTime(y, mo, d, hh, mm, ss);
      return local.toUtc();
    }

    final monthNames = <String, int>{
      "january": 1,
      "february": 2,
      "march": 3,
      "april": 4,
      "may": 5,
      "june": 6,
      "july": 7,
      "august": 8,
      "september": 9,
      "october": 10,
      "november": 11,
      "december": 12,
    };

    final mdy = RegExp(r"^([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})$");
    final m2 = mdy.firstMatch(s);
    if (m2 != null) {
      final mo = monthNames[m2.group(1)!.toLowerCase()];
      if (mo != null) {
        final d = int.parse(m2.group(2)!);
        final y = int.parse(m2.group(3)!);
        final local = DateTime(y, mo, d);
        return local.toUtc();
      }
    }

    return null;
  }

  static TimeZoneInfo resolveTimeZone({
    required DateTime instantUtc,
    required LiquidOptions options,
    Object? tzArg,
  }) {
    final override = tzArg ?? options.timezoneOffset;

    if (override is num) {
      final off = override.toInt();
      return TimeZoneInfo(offsetMinutes: off, nameForZ: null);
    }

    if (override is String) {
      final t = override.trim();
      final parsed = _parseOffsetStringToJsMinutes(t);
      if (parsed != null) {
        return TimeZoneInfo(offsetMinutes: parsed, nameForZ: t);
      }
      // Zone name: on ne sait pas calculer l’offset sans base TZ.
      // On garde l’heure locale runtime, mais %Z renverra le nom.
      final local = instantUtc.toLocal();
      final off = -local.timeZoneOffset.inMinutes;
      return TimeZoneInfo(offsetMinutes: off, nameForZ: t);
    }

    final local = instantUtc.toLocal();
    return TimeZoneInfo(
      offsetMinutes: -local.timeZoneOffset.inMinutes,
      nameForZ: local.timeZoneName,
    );
  }

  static int? _parseOffsetStringToJsMinutes(String s) {
    // Accept "+HHMM", "-HHMM", "+HH:MM", "-HH:MM"
    final m = RegExp(r"^([+-])(\d{2}):?(\d{2})$").firstMatch(s);
    if (m == null) return null;
    final sign = m.group(1) == "-" ? -1 : 1;
    final hh = int.parse(m.group(2)!);
    final mm = int.parse(m.group(3)!);
    final minutesLocalMinusUtc = sign * (hh * 60 + mm); // local - UTC
    // JS minutes offset = UTC - local
    return -minutesLocalMinusUtc;
  }

  static String format({
    required DateTime instantUtc,
    required String format,
    required TimeZoneInfo tz,
  }) {
    final local = instantUtc.subtract(Duration(minutes: tz.offsetMinutes));
    return _strftime(local, format, tz);
  }

  static String _strftime(DateTime dt, String fmt, TimeZoneInfo tz) {
    const monthsShort = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    const monthsLong = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    const wdaysShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const wdaysLong = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
    ];

    int wday0Sun(DateTime d) => d.weekday % 7; // Mon=1..Sun=7 => Sun=0
    int dayOfYear(DateTime d) {
      final start = DateTime.utc(d.year, 1, 1);
      return d.difference(start).inDays + 1;
    }

    String pad(int v, int width, String ch) {
      final s = v.abs().toString();
      if (width <= 0) return (v < 0 ? "-" : "") + s;
      final p = s.padLeft(width, ch);
      return (v < 0 ? "-" : "") + p;
    }

    String tzOffsetZ(int offsetMinutes) {
      final sign = offsetMinutes <= 0 ? "+" : "-";
      final m = offsetMinutes.abs();
      final hh = (m ~/ 60).toString().padLeft(2, "0");
      final mm = (m % 60).toString().padLeft(2, "0");
      return "$sign$hh$mm";
    }

    String ordinalSuffix(int n) {
      final mod100 = n % 100;
      if (mod100 >= 11 && mod100 <= 13) return "th";
      switch (n % 10) {
        case 1:
          return "st";
        case 2:
          return "nd";
        case 3:
          return "rd";
        default:
          return "th";
      }
    }

    final out = StringBuffer();
    for (var i = 0; i < fmt.length; i++) {
      final ch = fmt[i];
      if (ch != "%") {
        out.write(ch);
        continue;
      }
      if (i + 1 >= fmt.length) {
        out.write("%");
        continue;
      }

      var j = i + 1;
      String? flag;
      final fch = fmt[j];
      if (fch == "-" || fch == "_" || fch == "0") {
        flag = fch;
        j++;
      }
      if (j >= fmt.length) {
        out.write("%");
        break;
      }

      final code = fmt[j];
      i = j;

      String num2(int v, {bool noPad = false, bool spacePad = false}) {
        if (noPad) return v.toString();
        if (spacePad) return v.toString().padLeft(2, " ");
        return v.toString().padLeft(2, "0");
      }

      final noPad = flag == "-";
      final spacePadFlag = flag == "_";

      switch (code) {
        case "%":
          out.write("%");
          break;

        case "Y":
          out.write(pad(dt.year, 4, "0"));
          break;
        case "y":
          out.write((dt.year % 100).toString().padLeft(2, "0"));
          break;

        case "m":
          out.write(num2(dt.month, noPad: noPad, spacePad: spacePadFlag));
          break;

        case "B":
          out.write(monthsLong[dt.month - 1]);
          break;
        case "b":
          out.write(monthsShort[dt.month - 1]);
          break;

        case "d":
          out.write(num2(dt.day, noPad: noPad, spacePad: spacePadFlag));
          break;

        case "e":
          out.write(num2(dt.day, noPad: noPad, spacePad: true));
          break;

        case "H":
          out.write(num2(dt.hour, noPad: noPad, spacePad: spacePadFlag));
          break;
        case "I":
          final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          out.write(num2(h, noPad: noPad, spacePad: spacePadFlag));
          break;
        case "l":
          final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          out.write(num2(h, noPad: noPad, spacePad: true));
          break;

        case "M":
          out.write(num2(dt.minute, noPad: noPad, spacePad: spacePadFlag));
          break;
        case "S":
          out.write(num2(dt.second, noPad: noPad, spacePad: spacePadFlag));
          break;

        case "p":
          out.write(dt.hour < 12 ? "AM" : "PM");
          break;
        case "P":
          out.write(dt.hour < 12 ? "am" : "pm");
          break;

        case "a":
          out.write(wdaysShort[wday0Sun(dt)]);
          break;
        case "A":
          out.write(wdaysLong[wday0Sun(dt)]);
          break;

        case "w":
          out.write(wday0Sun(dt).toString());
          break;
        case "u":
          out.write(dt.weekday.toString()); // Mon=1..Sun=7
          break;

        case "j":
          out.write(dayOfYear(dt).toString().padLeft(3, "0"));
          break;

        case "F":
          out.write(
            "${dt.year.toString().padLeft(4, "0")}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")}",
          );
          break;
        case "T":
          out.write(
            "${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}:${dt.second.toString().padLeft(2, "0")}",
          );
          break;
        case "R":
          out.write(
            "${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}",
          );
          break;

        case "s":
          out.write((dt.millisecondsSinceEpoch ~/ 1000).toString());
          break;

        case "z":
          out.write(tzOffsetZ(tz.offsetMinutes));
          break;

        case "Z":
          if (tz.nameForZ != null && tz.nameForZ!.isNotEmpty) {
            out.write(tz.nameForZ);
          } else {
            out.write(tzOffsetZ(tz.offsetMinutes));
          }
          break;

        case "q":
          out.write(ordinalSuffix(dt.day));
          break;

        default:
          out.write("%");
          if (flag != null) out.write(flag);
          out.write(code);
          break;
      }
    }

    return out.toString();
  }
}
