import 'package:flutter_test/flutter_test.dart';

import 'package:jole_game/main.dart';

void main() {
  testWidgets('Jöle oyunu başlatma testi', (WidgetTester tester) async {
    // Uygulamayı oluştur
    await tester.pumpWidget(const JoleGameApp());

    // OYUNA BAŞLA butonunun görünür olduğunu doğrula
    expect(find.text('OYUNA BAŞLA'), findsOneWidget);

    // JÖLE başlığının görünür olduğunu doğrula
    expect(find.text('JÖLE'), findsOneWidget);
  });
}
