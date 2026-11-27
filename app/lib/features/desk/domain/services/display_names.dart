/// What a public screen may show and say: "مريم ع." for "مريم عبد الله", "يوسف ن." for
/// "يوسف النجار", but kunyas stay whole ("أبو سامي"). Same rules as the API's DisplayNames.java.
String? screenName(String? fullName) {
  if (fullName == null || fullName.trim().isEmpty) return null;
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first;
  const kunya = {'أبو', 'ابو', 'أم', 'ام', 'abu', 'umm', 'um'};
  if (kunya.contains(parts[0].toLowerCase())) return '${parts[0]} ${parts[1]}';
  var second = parts[1];
  if (second.endsWith('.')) return '${parts[0]} $second';
  if (second.startsWith('ال') && second.length > 2) second = second.substring(2);
  return '${parts[0]} ${String.fromCharCode(second.runes.first)}.';
}

/// Reads a check-in code from what the camera saw: the raw code, "mawid:CODE" or a ".../c/CODE" link.
String? checkInCodeFrom(String scanned) {
  var s = scanned.trim();
  final slash = s.lastIndexOf('/c/');
  if (slash >= 0) s = s.substring(slash + 3);
  final colon = s.lastIndexOf(':');
  if (colon >= 0 && !s.startsWith('http')) s = s.substring(colon + 1);
  final q = s.indexOf('?');
  if (q >= 0) s = s.substring(0, q);
  s = s.replaceAll('/', '').trim().toUpperCase();
  if (s.isEmpty || s.length > 16) return null;
  return s;
}
