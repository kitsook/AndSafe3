import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andsafe/utils/category_icons.dart';

Widget buildTestable(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Material(child: child),
  );
}

void main() {
  group('noteCategories enum', () {
    test('has 10 categories', () {
      expect(noteCategories.values.length, 10);
    });
  });

  group('getIconByCategory', () {
    testWidgets('returns CircleAvatar for valid category index', (tester) async {
      await tester.pumpWidget(buildTestable(getIconByCategory(0)));
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('returns CircleAvatar for negative index', (tester) async {
      await tester.pumpWidget(buildTestable(getIconByCategory(-1)));
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('returns CircleAvatar for out-of-range index', (tester) async {
      await tester.pumpWidget(buildTestable(getIconByCategory(100)));
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('category 0 has edit_rounded icon', (tester) async {
      await tester.pumpWidget(buildTestable(getIconByCategory(0)));
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    });

    testWidgets('category 1 has phone_rounded icon', (tester) async {
      await tester.pumpWidget(buildTestable(getIconByCategory(1)));
      expect(find.byIcon(Icons.phone_rounded), findsOneWidget);
    });

    testWidgets('category 2 has vpn_key_rounded icon', (tester) async {
      await tester.pumpWidget(buildTestable(getIconByCategory(2)));
      expect(find.byIcon(Icons.vpn_key_rounded), findsOneWidget);
    });

    testWidgets('category 3 has favorite_rounded icon', (tester) async {
      await tester.pumpWidget(buildTestable(getIconByCategory(3)));
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('category 4 has lock_rounded icon', (tester) async {
      await tester.pumpWidget(buildTestable(getIconByCategory(4)));
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('category 5 has computer_rounded icon', (tester) async {
      await tester.pumpWidget(buildTestable(getIconByCategory(5)));
      expect(find.byIcon(Icons.computer_rounded), findsOneWidget);
    });

    testWidgets('category 6 has attach_money_rounded icon', (tester) async {
      await tester.pumpWidget(buildTestable(getIconByCategory(6)));
      expect(find.byIcon(Icons.attach_money_rounded), findsOneWidget);
    });

    testWidgets('category 7 has calendar_today_rounded icon', (tester) async {
      await tester.pumpWidget(buildTestable(getIconByCategory(7)));
      expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
    });

    testWidgets('category 8 has settings_rounded icon', (tester) async {
      await tester.pumpWidget(buildTestable(getIconByCategory(8)));
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    });

    testWidgets('category 9 has folder_rounded icon', (tester) async {
      await tester.pumpWidget(buildTestable(getIconByCategory(9)));
      expect(find.byIcon(Icons.folder_rounded), findsOneWidget);
    });

    test('all categories produce unique icons', () {
      final icons = [
        Icons.edit_rounded,
        Icons.phone_rounded,
        Icons.vpn_key_rounded,
        Icons.favorite_rounded,
        Icons.lock_rounded,
        Icons.computer_rounded,
        Icons.attach_money_rounded,
        Icons.calendar_today_rounded,
        Icons.settings_rounded,
        Icons.folder_rounded,
      ];
      expect(icons.toSet().length, 10);
    });
  });
}
