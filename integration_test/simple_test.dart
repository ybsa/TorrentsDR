import 'package:flutter_test/flutter_test.dart';
import 'package:torrent_app/main.dart';
import 'package:torrent_app/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const TorrentApp());
    // Just verify the app builds without error
    expect(find.byType(TorrentApp), findsNothing); // Widget is wrapped
  });
}
