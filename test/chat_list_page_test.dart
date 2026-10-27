import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petguardian/pages/messages/chat_list_page.dart';

const String me = 'uid_me';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();

    // Profiles resolved by ChatListPage's cache.
    seedUser(firestore, 'uid_ayse', 'Ayşe Yılmaz');
    seedUser(firestore, 'uid_mert', 'Mert Demir');

    // Two conversations. "Merhaba" matches the first by message text.
    firestore.collection('messages').doc('c1').set({
      'participants': [me, 'uid_ayse'],
      'lastMessage': 'Merhaba Ayşe',
      'lastMessageType': 'text',
      'unreadCount': {me: 2},
    });
    firestore.collection('messages').doc('c2').set({
      'participants': [me, 'uid_mert'],
      'lastMessage': 'Fotoğraf hazır',
      'lastMessageType': 'image',
      'unreadCount': {me: 0},
    });
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ChatListPage(currentUserUID: me, firestore: firestore)),
    );
    await tester.pumpAndSettle();
  }

  group('ChatListPage', () {
    testWidgets('lists both conversations with recipient names', (tester) async {
      await pumpList(tester);

      expect(find.text('Mesajlar'), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Mert Demir'), findsOneWidget);
      expect(find.text('Merhaba Ayşe'), findsOneWidget);
      // image messages show the type label, not the raw text
      expect(find.text('📷 Fotoğraf'), findsOneWidget);
    });

    testWidgets('shows the unread badge for the conversation with unread', (tester) async {
      await pumpList(tester);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('search icon reveals a search field', (tester) async {
      await pumpList(tester);

      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Mesajlar'), findsNothing);
    });

    testWidgets('filters by recipient name', (tester) async {
      await pumpList(tester);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ayşe');
      await tester.pumpAndSettle();

      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Mert Demir'), findsNothing);
    });

    testWidgets('filters by message text, case-insensitively', (tester) async {
      await pumpList(tester);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'MERHABA');
      await tester.pumpAndSettle();

      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Mert Demir'), findsNothing);
    });

    testWidgets('shows a no-results state and can close the search', (tester) async {
      await pumpList(tester);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bulunamayacak-bir-kisi');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search_off), findsOneWidget);

      await tester.tap(find.text('Aramayı kapat'));
      await tester.pumpAndSettle();

      // Back to the full list.
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Mert Demir'), findsOneWidget);
    });

    testWidgets('closing search from the X button restores the full list', (tester) async {
      await pumpList(tester);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ayşe');
      await tester.pumpAndSettle();
      expect(find.text('Mert Demir'), findsNothing);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('Mert Demir'), findsOneWidget);
    });
  });
}

/// Seeds a user profile document.
void seedUser(FakeFirebaseFirestore firestore, String uid, String fullName) {
  firestore.collection('users').doc(uid).set({'fullName': fullName, 'photoURL': ''});
}