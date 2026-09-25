/// Tools whose runs are stored as History sessions.
enum SessionTool {
  ping('PING'),
  trace('TRACE'),
  ports('PORTS'),
  speed('SPEED'),
  loss('LOSS'),
  lan('LAN'),
  geo('GEO');

  const SessionTool(this.label);
  final String label;

  static SessionTool? byName(String name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}
