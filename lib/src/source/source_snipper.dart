String lineAtOffset(String source, int offset) {
  if (offset < 0) offset = 0;
  if (offset > source.length) offset = source.length;

  var start = offset;
  while (start > 0) {
    final c = source.codeUnitAt(start - 1);
    if (c == 10 || c == 13) break;
    start--;
  }

  var end = offset;
  while (end < source.length) {
    final c = source.codeUnitAt(end);
    if (c == 10 || c == 13) break;
    end++;
  }

  return source.substring(start, end);
}
