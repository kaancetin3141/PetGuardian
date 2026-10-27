import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:petguardian/stuff/formatters.dart';

void main() {
  // tr_TR symbols are not loaded by default. Any DateFormat('...', 'tr_TR')
  // throws a LocaleDataException unless this has run, which is exactly what
  // main() does for the real app.
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  group('relativeTimestamp', () {
    final now = DateTime(2026, 3, 15, 14, 30);

    test('shows the clock time for today', () {
      expect(
        AppFormatters.relativeTimestamp(DateTime(2026, 3, 15, 9, 5), now: now),
        '09:05',
      );
    });

    test('shows "Dün" for yesterday', () {
      expect(
        AppFormatters.relativeTimestamp(DateTime(2026, 3, 14, 23, 59), now: now),
        'Dün',
      );
    });

    test('shows the Turkish weekday name within the last week', () {
      // 2026-03-11 is a Wednesday -> "Çarşamba"
      expect(
        AppFormatters.relativeTimestamp(DateTime(2026, 3, 11, 8, 0), now: now),
        'Çarşamba',
      );
    });

    test('shows a numeric date once older than a week', () {
      expect(
        AppFormatters.relativeTimestamp(DateTime(2026, 3, 1, 8, 0), now: now),
        '01.03.26',
      );
    });

    test('does not throw for any age (regression: tr_TR was never initialised)', () {
      expect(
        () => AppFormatters.relativeTimestamp(DateTime(2019, 1, 1), now: DateTime(2026)),
        returnsNormally,
      );
    });
  });

  group('dayHeader', () {
    final now = DateTime(2026, 3, 15, 12);

    test('labels today as "Bugün"', () {
      expect(AppFormatters.dayHeader(DateTime(2026, 3, 15, 1), now: now), 'Bugün');
    });

    test('labels yesterday as "Dün"', () {
      expect(AppFormatters.dayHeader(DateTime(2026, 3, 14, 23), now: now), 'Dün');
    });

    test('formats older days in Turkish long form', () {
      expect(
        AppFormatters.dayHeader(DateTime(2026, 3, 1), now: now),
        '1 Mart 2026',
      );
    });
  });

  group('messageTypeLabel', () {
    test('describes every known non-text type', () {
      expect(AppFormatters.messageTypeLabel('image'), '📷 Fotoğraf');
      expect(AppFormatters.messageTypeLabel('location'), '📍 Konum paylaşıldı');
      expect(AppFormatters.messageTypeLabel('pet_card'), '🐾 Hayvan kartı paylaşıldı');
      expect(AppFormatters.messageTypeLabel('product_card'), '🛍️ Ürün kartı paylaşıldı');
    });

    test('falls back for unknown types', () {
      expect(AppFormatters.messageTypeLabel('text'), 'Mesaj');
      expect(AppFormatters.messageTypeLabel('something_new'), 'Mesaj');
      expect(AppFormatters.messageTypeLabel(''), 'Mesaj');
    });
  });

  group('messageTypeIcon', () {
    test('returns null for text so the row shows no icon', () {
      expect(AppFormatters.messageTypeIcon('text'), isNull);
      expect(AppFormatters.messageTypeIcon('unknown'), isNull);
    });

    test('returns an icon for each known non-text type', () {
      expect(AppFormatters.messageTypeIcon('image'), isNotNull);
      expect(AppFormatters.messageTypeIcon('location'), isNotNull);
      expect(AppFormatters.messageTypeIcon('pet_card'), isNotNull);
      expect(AppFormatters.messageTypeIcon('product_card'), isNotNull);
    });
  });
}