/// Normalizes to `+<digits>`; returns null if it can't be an international number.
/// Mirrors PhoneNumbers.normalize in the API.
String? normalizePhone(String raw) {
  var p = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (p.startsWith('00')) p = '+${p.substring(2)}';
  if (!p.startsWith('+')) p = '+$p';
  return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(p) ? p : null;
}
