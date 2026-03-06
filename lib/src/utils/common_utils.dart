DateTime? parseExifDate(String? raw) {
  if (raw == null) return null;
  try {
    final parts = raw.split(' ');
    final datePart = parts[0].replaceAll(':', '-');
    final timePart = parts.length > 1 ? parts[1] : '00:00:00';
    return DateTime.parse('$datePart $timePart');
  } catch (_) {
    return null;
  }
}

double? parseGps(String value, String ref) {
  try {
    final parts = value.split(', ');
    
    double parseFraction(String fraction) {
      final nums = fraction.split('/');
      return double.parse(nums[0]) / double.parse(nums[1]);
    }

    final degrees = parseFraction(parts[0]);
    final minutes = parseFraction(parts[1]);
    final seconds = parseFraction(parts[2]);

    double decimal = degrees + (minutes / 60) + (seconds / 3600);

    if (ref == 'S' || ref == 'W') decimal = -decimal;

    return decimal;
  } catch (_) {
    return null;
  }
}