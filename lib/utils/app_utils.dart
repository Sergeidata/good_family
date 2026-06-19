String extractAppName(String packageName) {
  if (packageName.isEmpty) {
    return "Unknown";
  }

  final parts = packageName.split(".");

  if (parts.isEmpty) {
    return packageName;
  }

  String name = parts.last;

  name = name.replaceAll("_", " ");

  if (name.isEmpty) {
    return packageName;
  }

  return name[0].toUpperCase() +
      name.substring(1);
}

String formatHoursMinutes(int seconds) {
  final hours = seconds ~/ 3600;

  final minutes =
      (seconds % 3600) ~/ 60;

  return "$hours ч $minutes мин";
}