import 'package:flutter_test/flutter_test.dart';
import 'package:obtainium/services/memory_probe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('memorySampleLine reports rss, peak, image cache and data counts', () {
    const context = (appCount: 42, folderCount: 3);
    final String line = memorySampleLine(context, const Duration(seconds: 10));
    expect(line, startsWith('memory probe +10s: rss='));
    expect(line, contains('MB peak='));
    expect(line, contains('imageCache='));
    expect(line, contains('apps=42 folders=3'));
    expect(line, contains('entries, limit'));
  });

  test('scheduleMemoryProbe is a no-op when the flag is off', () async {
    // The default build has memoryProbeEnabled == false, so nothing waits,
    // samples or logs.
    var calls = 0;
    await scheduleMemoryProbe(
      () => (appCount: 0, folderCount: 0),
      sink: (_) async => calls++,
    );
    expect(calls, 0);
  });
}
