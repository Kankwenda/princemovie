/// Petits formatages partagés.

/// Formate une taille en octets : 0 Ko, 1,2 Mo, 3,4 Go, ...
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 Ko';
  const units = <String>['o', 'Ko', 'Mo', 'Go'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final decimals = size >= 100 ? 0 : 1;
  // Virgule française : « 1,2 Go » (comme dans les libellés de démo).
  final value = size.toStringAsFixed(decimals).replaceAll('.', ',');
  return '$value ${units[unit]}';
}

/// Formate une durée en mm:ss ou hh:mm:ss.
String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$mm:$ss';
  return '$mm:$ss';
}
