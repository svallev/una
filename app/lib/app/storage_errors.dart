/// ¿El error se debe a falta de espacio? (ENOSPC / SQLITE_FULL)
bool isNoSpaceError(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('no space left') ||
      s.contains('sqlite_full') ||
      s.contains('database or disk is full') ||
      s.contains('errno = 28');
}
