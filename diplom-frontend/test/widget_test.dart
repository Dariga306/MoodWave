import 'package:flutter_test/flutter_test.dart';

import 'package:moodwave/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Используем правильный виджет приложения
    await tester.pumpWidget(const MoodWaveApp());

    // Здесь проверка будет зависеть от того, что есть в вашем SplashScreen или LoginScreen
    // Если хотите, можно проверить, что на экране есть текст 'MoodWave'
    expect(find.text('MoodWave'), findsOneWidget);
  });
}