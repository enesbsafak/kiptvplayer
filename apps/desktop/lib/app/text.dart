/// Text compared the way people type: case, Turkish dotted/dotless i and
/// diacritics ignored ("BILIM", "Bilim", "bılım" all match "bilim").
String foldText(String s) {
  const from = 'İIıÇçĞğÖöŞşÜüÂâÎîÛû';
  const to = 'iiiccggoossuuaaiiuu';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch.toLowerCase());
  }
  return b.toString();
}
