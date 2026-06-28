import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const PokemonScraperApp());
    // Verify the app builds and shows something
    expect(find.byType(PokemonScraperApp), findsOneWidget);
  });
}
