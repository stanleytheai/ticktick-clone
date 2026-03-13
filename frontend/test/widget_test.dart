import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/app.dart';

void main() {
  testWidgets('App renders auth gate', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TickTickApp()),
    );
    // App should render without crashing
    expect(find.byType(TickTickApp), findsOneWidget);
  });
}
