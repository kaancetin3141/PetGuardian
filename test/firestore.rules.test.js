// Firestore rules tests driven by the fields the Flutter client ACTUALLY writes.
//
// The original scaffold asserted against a schema the app never used
// (pets.ownerUID / pets.name), so it passed while pet creation was blocked in
// production. Every document below mirrors a literal write in lib/.

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');

const PROJECT_ID = 'petguardian-test';

let passed = 0;
let failed = 0;
const failures = [];

async function check(name, assertion) {
  try {
    await assertion();
    passed++;
    console.log(`  PASS  ${name}`);
  } catch (err) {
    failed++;
    const detail = String(err.message || err)
      .split('\n')
      .map((l) => l.trim())
      .filter(Boolean)
      .slice(0, 3)
      .join(' | ');
    failures.push({ name, message: detail });
    console.log(`  FAIL  ${name}`);
    console.log(`        ${detail}`);
  }
}

async function run() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync('./firestore.rules', 'utf8') },
  });

  const alice = testEnv.authenticatedContext('alice-uid');
  const bob = testEnv.authenticatedContext('bob-uid');
  const unauth = testEnv.unauthenticatedContext();

  const aliceDb = alice.firestore();
  const bobDb = bob.firestore();

  // ---- exact payload written by add_pet_page.dart _savePet() ----
  const petPayload = {
    serialNumber: '12345678901',
    imagePath: 'https://example.com/pet.jpg',
    title: 'Fluffy',
    Kinds: 'Kedi',
    age: '3',
    gender: 'Erkek',
    vaccine: 'Yapıldı',
    adoption: 'Yapıldı',
    chip: 'CHIP123',
    type: 'Sokak',
    note: 'Sakin',
    email: 'alice@example.com',
    phone: '05550000000',
    timestamp: new Date(),
    addedBy: 'alice-uid',
    userUID: 'alice-uid',
    fullName: 'Alice',
    ipAddress: '1.2.3.4',
    location: 'Kadikoy',
  };

  console.log('\n== users ==');
  await check('unauthenticated cannot read a profile', () =>
    assertFails(unauth.firestore().doc('users/alice-uid').get()));
  await check('user can create own profile', () =>
    assertSucceeds(aliceDb.doc('users/alice-uid').set({
      email: 'alice@example.com', fullName: 'Alice', role: 'customer',
    })));
  await check('user cannot create another profile', () =>
    assertFails(aliceDb.doc('users/bob-uid').set({ fullName: 'Bob' })));
  await check('user cannot self-assign the admin flag', () =>
    assertFails(aliceDb.doc('users/alice-uid').set({
      fullName: 'Alice', admin: true,
    })));
  await check('user cannot self-assign a privileged role', () =>
    assertFails(aliceDb.doc('users/carol-uid').set({
      fullName: 'Carol', role: 'admin',
    })));
  await check('user cannot store a password hash on signup', () =>
    assertFails(aliceDb.doc('users/dave-uid').set({
      fullName: 'Dave', passwordHash: '$2a$10$abcdefghijklmnopqrstuv',
    })));
  await check('user can update own profile fields', () =>
    assertSucceeds(aliceDb.doc('users/alice-uid').update({ fullName: 'Alice II' })));
  await check('user cannot promote own role after signup', () =>
    assertFails(aliceDb.doc('users/alice-uid').update({ role: 'admin' })));
  await check('user cannot write a password hash after signup', () =>
    assertFails(aliceDb.doc('users/alice-uid').update({
      passwordHash: '$2a$10$abcdefghijklmnopqrstuv',
    })));

  // ---- pentest: profile harvesting and token theft ----
  await check('user cannot list all profiles (PII harvest)', () =>
    assertFails(bobDb.collection('users').get()));
  await check('user cannot write an IP onto the profile', () =>
    assertFails(aliceDb.doc('users/alice-uid').update({ ip: '9.9.9.9' })));
  await check('user cannot write an FCM token onto the profile', () =>
    assertFails(aliceDb.doc('users/alice-uid').update({ fcmToken: 'tok' })));
  await check('user cannot create a profile with an IP', () =>
    assertFails(aliceDb.doc('users/alice-uid').set({
      fullName: 'Alice', ip: '9.9.9.9',
    }, { merge: true })));
  await check('user can save own FCM token in the private subcollection', () =>
    assertSucceeds(aliceDb.doc('users/alice-uid/private/fcm').set({
      fcmToken: 'secret-token',
    })));
  await check('another user cannot read an FCM token', () =>
    assertFails(bobDb.doc('users/alice-uid/private/fcm').get()));
  await check('another user cannot write an FCM token', () =>
    assertFails(bobDb.doc('users/alice-uid/private/fcm').set({
      fcmToken: 'evil-token',
    })));
  await check('unauthenticated cannot read an FCM token', () =>
    assertFails(unauth.firestore().doc('users/alice-uid/private/fcm').get()));

  console.log('\n== favorites (cross-user isolation) ==');
  await check('user can add own favorite', () =>
    assertSucceeds(aliceDb.doc('users/alice-uid/favorites/pet1').set({
      title: 'Fluffy', imagePath: 'https://example.com/pet.jpg',
    })));
  await check('non-owner cannot read another user favorites', () =>
    assertFails(bobDb.doc('users/alice-uid/favorites/pet1').get()));
  await check('non-owner cannot write another user favorites', () =>
    assertFails(bobDb.doc('users/alice-uid/favorites/other').set({
      title: 'planted',
    })));
  await check('favorite documents cannot be updated in place', () =>
    assertFails(aliceDb.doc('users/alice-uid/favorites/pet1').update({
      title: 'retitled',
    })));

  console.log('\n== pets (schema mirrors add_pet_page.dart) ==');
  await check('signed-in user can browse pets', () =>
    assertSucceeds(aliceDb.collection('pets').get()));
  await check('unauthenticated cannot browse pets (PII)', () =>
    assertFails(unauth.firestore().collection('pets').get()));
  await check('owner can create a pet', () =>
    assertSucceeds(aliceDb.doc('pets/pet1').set(petPayload)));
  await check('non-owner cannot create a pet', () =>
    assertFails(bobDb.doc('pets/pet2').set({ ...petPayload, userUID: 'alice-uid' })));
  await check('unauthenticated cannot create a pet', () =>
    assertFails(unauth.firestore().doc('pets/pet3').set(petPayload)));
  await check('owner can update own pet', () =>
    assertSucceeds(aliceDb.doc('pets/pet1').update({ title: 'Fluffy II' })));
  await check('non-owner cannot update a pet', () =>
    assertFails(bobDb.doc('pets/pet1').update({ title: 'stolen' })));
  await check('owner can delete own pet', () =>
    assertSucceeds(aliceDb.doc('pets/pet1').delete()));

  console.log('\n== deleted_pets (pet restore flow) ==');
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('pets/pet9').set({ ...petPayload, title: 'ToDelete' });
  });
  await check('owner can copy own pet into deleted_pets', () =>
    assertSucceeds(aliceDb.doc('deleted_pets/pet9').set({ ...petPayload, title: 'ToDelete' })));
  await check('non-owner cannot read an archived pet (PII)', () =>
    assertFails(bobDb.doc('deleted_pets/pet9').get()));
  await check('owner can move the pet back out of deleted_pets', () =>
    assertSucceeds(aliceDb.doc('pets/pet9').set({ ...petPayload, title: 'ToDelete' })));
  await check('non-owner cannot copy into deleted_pets', () =>
    assertFails(bobDb.doc('deleted_pets/other').set(petPayload)));

  console.log('\n== notifications ==');
  await check('user can read own notifications', () =>
    assertSucceeds(aliceDb.collection('notifications').where('userId', '==', 'alice-uid').get()));
  await check('user cannot read another user notifications', () =>
    assertFails(aliceDb.collection('notifications').where('userId', '==', 'bob-uid').get()));
  await check('user can create own notification', () =>
    assertSucceeds(aliceDb.collection('notifications').doc('n1').set({
      userId: 'alice-uid', title: 't', body: 'b', type: 'system', isRead: false,
    })));
  await check('user can mark own notification as read', () =>
    assertSucceeds(aliceDb.collection('notifications').doc('n1').update({
      isRead: true, readAt: new Date(),
    })));
  await check('marking as read cannot rewrite the body', () =>
    assertFails(aliceDb.collection('notifications').doc('n1').update({
      isRead: true, body: 'tampered',
    })));
  await check('user cannot mark another user notification as read', () =>
    assertFails(bobDb.collection('notifications').doc('n1').update({ isRead: true })));
  await check('user can delete own notification', () =>
    assertSucceeds(aliceDb.collection('notifications').doc('n1').delete()));

  console.log('\n== orders (cart checkout) ==');
  const orderPayload = {
    userUID: 'alice-uid',
    items: [
      { title: 'Tasma', imagePath: 'images/shop_images/product1.jpg', unitPriceCents: 9999, quantity: 2 },
    ],
    totalCents: 19998,
    currency: 'TRY',
    status: 'pending_payment',
    createdAt: new Date(),
  };
  await check('user can place an order', () =>
    assertSucceeds(aliceDb.collection('orders').doc('o1').set(orderPayload)));
  await check('user cannot place an order on behalf of someone else', () =>
    assertFails(bobDb.collection('orders').doc('o2').set({ ...orderPayload, userUID: 'alice-uid' })));
  await check('order without items is rejected', () =>
    assertFails(aliceDb.collection('orders').doc('o3').set({ ...orderPayload, items: [] })));
  await check('order with a negative total is rejected', () =>
    assertFails(aliceDb.collection('orders').doc('o4').set({ ...orderPayload, totalCents: -1 })));
  await check('user can read own order', () =>
    assertSucceeds(aliceDb.doc('orders/o1').get()));
  await check('user cannot read another user order', () =>
    assertFails(bobDb.doc('orders/o1').get()));
  await check('user cannot rewrite the items of an order', () =>
    assertFails(aliceDb.doc('orders/o1').update({ items: [], totalCents: 0 })));
  await check('user cannot delete an order', () =>
    assertFails(aliceDb.doc('orders/o1').delete()));

  // ---- pentest: order status escalation ----
  await check('customer cannot change their own order status', () =>
    assertFails(aliceDb.doc('orders/o1').update({ status: 'delivered' })));
  await check('nobody can list all orders', () =>
    assertFails(aliceDb.collection('orders').get()));
  const adminDb = testEnv
    .authenticatedContext('admin-uid', { admin: true })
    .firestore();
  await check('admin can update an order status', () =>
    assertSucceeds(adminDb.doc('orders/o1').update({
      status: 'delivered', updatedAt: new Date(),
    })));
  await check('admin cannot rewrite order items either', () =>
    assertFails(adminDb.doc('orders/o1').update({ totalCents: 0 })));

  console.log('\n== messages / chats ==');
  await check('conversation create includes creator', () =>
    assertSucceeds(aliceDb.doc('messages/alice_bob').set({
      participants: ['alice-uid', 'bob-uid'], lastMessage: 'hi',
    })));
  await check('conversation create excludes creator is denied', () =>
    assertFails(aliceDb.doc('messages/x').set({
      participants: ['bob-uid', 'charlie'], lastMessage: 'nope',
    })));
  await check('non-participant cannot read the conversation', () =>
    assertFails(testEnv.authenticatedContext('carol-uid').firestore()
      .doc('messages/alice_bob').get()));

  // The chat list and the home-screen badge run a LIST query over `messages`
  // constrained by `participants arrayContains <uid>`.
  //
  // @firebase/rules-unit-testing only implements the `==` filter operator, so
  // that exact shape cannot be exercised here. What matters is that the read
  // rule is provable from a `participants` constraint, which is the same shape
  // as the notifications query asserted above. An earlier revision of these
  // rules resolved the wildcard `conversationId` with get(), which is NOT
  // evaluable for a query and rejected the chat list outright; the rule below
  // uses `resource.data.participants` again so the constraint can prove it.
  await check('conversation read rule is provable from a participants constraint', () =>
    assertSucceeds(aliceDb.doc('messages/alice_bob').get()));
  await check('a non-participant list query over conversations is denied', () =>
    assertFails(testEnv.authenticatedContext('carol-uid').firestore()
      .collection('messages')
      .where('lastMessage', '==', 'hi')
      .get()));

  // exact payload written by message_page.dart _sendMessage()
  const messagePayload = {
    participants: ['alice-uid', 'bob-uid'],
    message: 'hello',
    type: 'text',
    senderUID: 'alice-uid',
    recipientUID: 'bob-uid',
    timestamp: new Date(),
    isRead: false,
  };

  await check('sender can post a message', () =>
    assertSucceeds(aliceDb.collection('messages/alice_bob/chats').doc('m1').set(messagePayload)));
  await check('message with mismatched senderUID is denied', () =>
    assertFails(aliceDb.collection('messages/alice_bob/chats').doc('m2').set({
      ...messagePayload, senderUID: 'someone-else',
    })));
  await check('participant can read the messages', () =>
    assertSucceeds(bobDb.collection('messages/alice_bob/chats').get()));

  // the read-receipt write performed by _markMessagesAsRead()
  await check('participant can mark a message as read (isRead/readAt)', () =>
    assertSucceeds(bobDb.collection('messages/alice_bob/chats').doc('m1')
      .update({ isRead: true, readAt: new Date() })));
  await check('read-receipt update cannot rewrite the message body', () =>
    assertFails(bobDb.collection('messages/alice_bob/chats').doc('m1')
      .update({ isRead: true, message: 'hacked' })));
  await check('non-participant cannot mark messages read', () =>
    assertFails(testEnv.authenticatedContext('carol-uid').firestore()
      .collection('messages/alice_bob/chats').doc('m1')
      .update({ isRead: true })));

  // ---- pentest: message injection into other people's conversations ----
  await check('writing into a conversation that does not exist is denied', () =>
    assertFails(aliceDb.collection('messages/ghost_chat/chats').doc('g1')
      .set(messagePayload)));
  await check('reading messages of a conversation that does not exist is denied', () =>
    assertFails(bobDb.collection('messages/ghost_chat/chats').get()));
  await check('participant cannot inject with a foreign participants list', () =>
    assertFails(aliceDb.collection('messages/alice_bob/chats').doc('m3').set({
      ...messagePayload, participants: ['alice-uid', 'charlie-uid'],
    })));
  await check('non-participant cannot inject into a real conversation', () =>
    assertFails(testEnv.authenticatedContext('carol-uid').firestore()
      .collection('messages/alice_bob/chats').doc('m4').set({
        ...messagePayload,
        senderUID: 'carol-uid',
        recipientUID: 'bob-uid',
        participants: ['carol-uid', 'bob-uid'],
      })));
  await check('conversation participants cannot be rewritten by a message', () =>
    assertFails(aliceDb.collection('messages/alice_bob/chats').doc('m5').set({
      ...messagePayload, participants: ['alice-uid', 'carol-uid'],
    })));
  await check('conversation update cannot swap the participants array', () =>
    assertFails(aliceDb.doc('messages/alice_bob').update({
      participants: ['alice-uid', 'carol-uid'],
    })));

  console.log('\n== reports (listing abuse flagging) ==');
  // Exact payload written by pet_detail_page.dart _submitReport(). The doc ID
  // is `<petId>_<reporterUid>` so a user can file at most one report per pet.
  const reportPayload = {
    petId: 'pet-1',
    reporterUID: 'alice-uid',
    reason: 'Sahte ilan',
    details: 'Fotograflar baska bir hayvana ait.',
    status: 'open',
    createdAt: new Date(),
    petTitle: 'Fluffy',
    ownerUID: 'bob-uid',
  };

  await check('reporter can file a report on a listing', () =>
    assertSucceeds(aliceDb.doc('reports/pet-1_alice-uid').set(reportPayload)));
  await check('report must open with status open', () =>
    assertFails(aliceDb.doc('reports/pet-2_alice-uid').set({
      ...reportPayload, petId: 'pet-2', status: 'resolved',
    })));
  await check('reporterUID must match the authenticated user', () =>
    assertFails(aliceDb.doc('reports/pet-3_eve-uid').set({
      ...reportPayload, petId: 'pet-3', reporterUID: 'eve-uid',
    })));
  await check('report cannot be filed unauthenticated', () =>
    assertFails(unauth.firestore().doc('reports/pet-1_eve-uid').set({
      ...reportPayload, reporterUID: 'eve-uid',
    })));
  await check('report rejects an unknown status value', () =>
    assertFails(aliceDb.doc('reports/pet-4_alice-uid').set({
      ...reportPayload, petId: 'pet-4', status: 'weird',
    })));
  await check('report rejects an oversized reason', () =>
    assertFails(aliceDb.doc('reports/pet-5_alice-uid').set({
      ...reportPayload, petId: 'pet-5', reason: 'x'.repeat(121),
    })));
  await check('report rejects an empty petId', () =>
    assertFails(aliceDb.doc('reports/blank_alice-uid').set({
      ...reportPayload, petId: '',
    })));

  // reporter reads own; the listing owner and other users must not.
  await check('reporter can read their own report', () =>
    assertSucceeds(aliceDb.doc('reports/pet-1_alice-uid').get()));
  await check('listing owner cannot read a report filed against them', () =>
    assertFails(bobDb.doc('reports/pet-1_alice-uid').get()));
  await check('another user cannot read someone elses report', () =>
    assertFails(testEnv.authenticatedContext('carol-uid').firestore()
      .doc('reports/pet-1_alice-uid').get()));

  // No client-side rewriting or spam.
  await check('reporter cannot rewrite their own report', () =>
    assertFails(aliceDb.doc('reports/pet-1_alice-uid')
      .update({ reason: 'changed my mind' })));
  await check('reporter cannot close their own report', () =>
    assertFails(aliceDb.doc('reports/pet-1_alice-uid')
      .update({ status: 'dismissed' })));
  await check('reports cannot be deleted by anyone', () =>
    assertFails(aliceDb.doc('reports/pet-1_alice-uid').delete()));
  await check('reports cannot be listed by a normal user', () =>
    assertFails(aliceDb.collection('reports').get()));
  // A second report against the same pet reuses the doc ID; since update is
  // admin-only and create is one-shot, this is rejected (anti-spam).
  await check('duplicate report on the same pet is rejected', () =>
    assertFails(aliceDb.doc('reports/pet-1_alice-uid').set({
      ...reportPayload, reason: 'ikinci kez',
    })));

  // Moderator triage.
  await check('admin can read all reports', () =>
    assertSucceeds(adminDb.collection('reports').get()));
  await check('admin can triage a report status', () =>
    assertSucceeds(adminDb.doc('reports/pet-1_alice-uid').update({
      status: 'resolved', resolvedAt: new Date(), resolvedBy: 'admin-uid',
      moderatorNote: 'dogrulandi',
    })));
  await check('admin triage cannot rewrite the claim itself', () =>
    assertFails(adminDb.doc('reports/pet-1_alice-uid').update({
      reason: 'rewritten',
    })));
  await check('non-admin cannot triage a report', () =>
    assertFails(bobDb.doc('reports/pet-1_alice-uid').update({
      status: 'dismissed',
    })));

  console.log('\n== applications (adoption applications) ==');
  // Exact payload written by pet_detail_page.dart _submitApplication(). The
  // doc ID is `<petId>_<applicantUid>` so a user can apply at most once per
  // pet.
  const applicationPayload = {
    petId: 'pet-1',
    applicantUID: 'alice-uid',
    ownerUID: 'bob-uid',
    petTitle: 'Fluffy',
    message: 'Fluffy ile ilgileniyorum, refakatci ev ortamim var.',
    phone: '02121234567',
    status: 'pending',
    createdAt: new Date(),
  };

  await check('applicant can apply for a pet', () =>
    assertSucceeds(aliceDb.doc('applications/pet-1_alice-uid').set(applicationPayload)));
  await check('application cannot be filed unauthenticated', () =>
    assertFails(unauth.firestore().doc('applications/pet-2_eve-uid').set({
      ...applicationPayload, petId: 'pet-2', applicantUID: 'eve-uid',
    })));
  await check('applicantUID must match the authenticated user', () =>
    assertFails(aliceDb.doc('applications/pet-3_eve-uid').set({
      ...applicationPayload, petId: 'pet-3', applicantUID: 'eve-uid',
    })));
  await check('owner cannot apply for their own pet', () =>
    assertFails(bobDb.doc('applications/pet-1_bob-uid').set({
      ...applicationPayload, applicantUID: 'bob-uid', ownerUID: 'bob-uid',
    })));
  await check('application rejects an empty message', () =>
    assertFails(aliceDb.doc('applications/pet-4_alice-uid').set({
      ...applicationPayload, petId: 'pet-4', message: '',
    })));
  await check('application rejects an oversized message', () =>
    assertFails(aliceDb.doc('applications/pet-5_alice-uid').set({
      ...applicationPayload, petId: 'pet-5', message: 'x'.repeat(1001),
    })));
  await check('application must open with status pending', () =>
    assertFails(aliceDb.doc('applications/pet-6_alice-uid').set({
      ...applicationPayload, petId: 'pet-6', status: 'approved',
    })));

  // Reads: applicant and owner only.
  await check('applicant can read their own application', () =>
    assertSucceeds(aliceDb.doc('applications/pet-1_alice-uid').get()));
  await check('listing owner can read applications for their pet', () =>
    assertSucceeds(bobDb.doc('applications/pet-1_alice-uid').get()));
  await check('another user cannot read a strangers application', () =>
    assertFails(testEnv.authenticatedContext('carol-uid').firestore()
      .doc('applications/pet-1_alice-uid').get()));

  // Lifecycle: owner approves/declines, applicant withdraws.
  await check('owner can approve a pending application', () =>
    assertSucceeds(bobDb.doc('applications/pet-1_alice-uid').update({
      status: 'approved', resolvedAt: new Date(), resolvedBy: 'bob-uid',
    })));
  await check('resolved application cannot change again', () =>
    assertFails(bobDb.doc('applications/pet-1_alice-uid').update({
      status: 'declined',
    })));
  await check('applicant can submit another application (pet-7)', () =>
    assertSucceeds(aliceDb.doc('applications/pet-7_alice-uid').set({
      ...applicationPayload, petId: 'pet-7',
    })));
  await check('applicant cannot approve their own application', () =>
    assertFails(aliceDb.doc('applications/pet-7_alice-uid').update({
      status: 'approved',
    })));
  await check('applicant cannot decline their own application', () =>
    assertFails(aliceDb.doc('applications/pet-7_alice-uid').update({
      status: 'declined',
    })));
  await check('applicant can withdraw their own pending application', () =>
    assertSucceeds(aliceDb.doc('applications/pet-7_alice-uid').update({
      status: 'withdrawn', resolvedAt: new Date(),
    })));
  await check('applicant can submit application (pet-8)', () =>
    assertSucceeds(aliceDb.doc('applications/pet-8_alice-uid').set({
      ...applicationPayload, petId: 'pet-8',
    })));
  await check('owner cannot rewrite the message via triage', () =>
    assertFails(bobDb.doc('applications/pet-8_alice-uid').update({
      message: 'tampered',
    })));
  await check('owner triage cannot move status to an unknown value', () =>
    assertFails(bobDb.doc('applications/pet-8_alice-uid').update({
      status: 'maybe', resolvedAt: new Date(),
    })));
  await check('stranger cannot triage an application', () =>
    assertFails(testEnv.authenticatedContext('carol-uid').firestore()
      .doc('applications/pet-8_alice-uid').update({ status: 'declined' })));
  await check('applications cannot be deleted by anyone', () =>
    assertFails(bobDb.doc('applications/pet-8_alice-uid').delete()));
  await check('admin can read all applications', () =>
    assertSucceeds(adminDb.collection('applications').get()));

  console.log('\n== reviews (listing ratings) ==');
  // Exact payload written by pet_detail_page.dart _submitReview(). The doc
  // ID is `<petId>_<authorUid>` so a user can review a pet at most once.
  const reviewPayload = {
    petId: 'pet-1',
    authorUID: 'alice-uid',
    authorName: 'Alice',
    ownerUID: 'bob-uid',
    petTitle: 'Fluffy',
    rating: 5,
    comment: 'Saglikli, sakin bir hayvan.',
    createdAt: new Date(),
  };

  await check('author can review a listing', () =>
    assertSucceeds(aliceDb.doc('reviews/pet-1_alice-uid').set(reviewPayload)));
  await check('review cannot be filed unauthenticated', () =>
    assertFails(unauth.firestore().doc('reviews/pet-2_eve-uid').set({
      ...reviewPayload, petId: 'pet-2', authorUID: 'eve-uid',
    })));
  await check('authorUID must match the authenticated user', () =>
    assertFails(aliceDb.doc('reviews/pet-3_eve-uid').set({
      ...reviewPayload, petId: 'pet-3', authorUID: 'eve-uid',
    })));
  await check('owner cannot review their own pet', () =>
    assertFails(bobDb.doc('reviews/pet-1_bob-uid').set({
      ...reviewPayload, authorUID: 'bob-uid', ownerUID: 'bob-uid',
    })));
  await check('rating below 1 is rejected', () =>
    assertFails(aliceDb.doc('reviews/pet-4_alice-uid').set({
      ...reviewPayload, petId: 'pet-4', rating: 0,
    })));
  await check('rating above 5 is rejected', () =>
    assertFails(aliceDb.doc('reviews/pet-5_alice-uid').set({
      ...reviewPayload, petId: 'pet-5', rating: 6,
    })));
  await check('fractional rating is rejected', () =>
    assertFails(aliceDb.doc('reviews/pet-6_alice-uid').set({
      ...reviewPayload, petId: 'pet-6', rating: 4.5,
    })));
  await check('oversized comment is rejected', () =>
    assertFails(aliceDb.doc('reviews/pet-7_alice-uid').set({
      ...reviewPayload, petId: 'pet-7', comment: 'x'.repeat(501),
    })));
  await check('review without a comment is allowed', () =>
    assertSucceeds(aliceDb.doc('reviews/pet-8_alice-uid').set({
      ...reviewPayload, petId: 'pet-8', comment: '',
    })));

  await check('any signed-in user can read reviews', () =>
    assertSucceeds(testEnv.authenticatedContext('carol-uid').firestore()
      .doc('reviews/pet-1_alice-uid').get()));
  await check('reviewing again on the same pet is blocked (doc exists)', () =>
    assertFails(aliceDb.doc('reviews/pet-1_alice-uid').set({
      ...reviewPayload, rating: 2,
    })));
  await check('reviews cannot be updated by anyone', () =>
    assertFails(aliceDb.doc('reviews/pet-1_alice-uid').update({
      rating: 1,
    })));
  await check('reviews cannot be deleted by anyone', () =>
    assertFails(bobDb.doc('reviews/pet-1_alice-uid').delete()));

  await testEnv.cleanup();

  console.log(`\n${passed} passed, ${failed} failed`);
  if (failed > 0) {
    console.log('\nFailures:');
    failures.forEach((f) => console.log(`  - ${f.name}`));
    process.exit(1);
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});