Overview
========

This document explains the Firestore security rules in this repository and how to
run the rules unit tests locally or in CI.

Files
- `firestore.rules`: the deployed rules.
- `firebase.json`: emulator config used by the rules tests.
- `test/firestore.rules.test.js`: rules tests driven by the fields the Flutter
  client actually writes.

Guiding principles
- Least privilege: a client may only read or write data it is authorized for.
- Ownership and privilege changes are enforced server side, never trusted from
  the client payload.
- Admin is assumed to be a custom claim (`admin`) or `role == 'admin'`.

Field names must match the client
--------------------------------
The rules validate the *real* payload written by the Dart code. Mismatches
silently break the app in production, because the permission errors are
swallowed by `debugPrint` calls.

| Document | Rule previously required | Client actually writes |
|---|---|---|
| `pets/{petId}` | `ownerUID`, `name` | `userUID`, `title` |
| `messages/{id}/chats/{msgId}` update | `delivered`, `read` | `isRead`, `readAt` |

`notifications` and `deleted_pets` had **no rules at all**, so every read and
write to them was rejected.

Subcollection reads are authorized from the parent
-------------------------------------------------
`messages/{id}/chats` is loaded with `orderBy()` / `where()` queries, and
`resource` is not available when authorizing a query. The `chats` read rule
therefore resolves the conversation document with `get()` and checks its
`participants`. Using `resource.data.participants` on the child compiles but
rejects every query, which meant the message list never loaded.

Authentication
--------------
Passwords are owned by Firebase Authentication. `login_page.dart` previously
compared a bcrypt hash read from the `users` collection instead of calling
`signInWithEmailAndPassword`, so no Auth session was ever established, every
Firestore read afterwards was rejected, and login could not succeed at all.
The mirrored `passwordHash` field has been removed; the rules now refuse to
create or update it, so copies cannot be reintroduced.

Key rule highlights
- `/users/{userId}`: any signed-in user can read profiles (the chat list resolves
  recipient names and avatars). The owner may update their own document but may
  not set `admin`, may only set `role: 'customer'` at signup, and may not change
  `role`/`admin`/`passwordHash` afterwards. Admins may.
- `/users/{userId}/favorites/{petId}`: only that user can read or write their
  favorites.
- `/pets/{petId}`: signed-in read (browsing). Write requires
  `userUID == request.auth.uid` plus a non-empty `title`. The owner cannot
  reassign a pet, because an update that changes `userUID` is rejected.
- `/deleted_pets/{petId}`: soft-delete archive used by pet delete/restore. Not
  publicly readable, because these documents carry the owner's email and phone.
- `/notifications/{notificationId}`: readable only when `userId == auth.uid`.
  Updates may only touch `isRead` / `readAt`.
- `/messages/{conversationId}`: participants only; clients cannot delete, and
  `participants` cannot be rewritten once the conversation exists.
- `/messages/{conversationId}/chats/{messageId}`: `senderUID` must equal the
  authenticated user and `recipientUID` must not. Updates are limited to
  `isRead` / `readAt` via `diff().affectedKeys()`, so a participant cannot
  rewrite somebody else's message body.
- `/orders/{orderId}`: written by `cart_page.dart` when the customer confirms a
  purchase. `userUID` must be the buyer, `items` must be non-empty and
  `totalCents` must be a non-negative integer. Buyers can read their own orders
  only; they can update `status` / `cancelledReason` but never `items` or
  `totalCents`, and cannot delete an order. Money is stored as integer cents, not
  a floating point total.

There is no payment provider wired up, so orders are created with
`status: 'pending_payment'` and stay there until an operator fulfils them.

Running the tests
-----------------
The tests need the Firestore emulator, which requires **Java 11+**.

```bash
npm install
npx firebase-tools emulators:exec --only firestore \
  --project petguardian-test "node test/firestore.rules.test.js"
```

Running `node test/firestore.rules.test.js` on its own fails with
"The host and port of the firestore emulator must be specified" — the emulator
has to be started first. `emulators:exec` handles that.

CI
--
`.github/workflows/ci.yml` runs the same command, after `actions/setup-java`
installs Temurin 17.

Notes
-----
- Test payloads mirror literal writes in `lib/` (see `add_pet_page.dart`,
  `message_page.dart`, `notification_page.dart`). If a document shape changes,
  update both the rules and these tests together.
- Pet documents embed the owner's `email`, `phone` and `ipAddress`. Reads are
  restricted to signed-in users, but any signed-in user can still read another
  user's pet documents. If that matters, move owner contact data into a
  private collection or strip it from the shared `pets` documents.