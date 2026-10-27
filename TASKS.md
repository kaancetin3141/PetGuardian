# PetGuardian - Geliştirme Görev Listesi

## 🎯 Mesajlaşma ve Bildirim Sistemi İyileştirmeleri

### 1. FCM Push Notification Entegrasyonu
- [x] `main.dart` - Firebase Messaging başlatma ve background handler ekleme
- [x] `login_page.dart` - Giriş yapıldığında FCM token alıp Firestore'a kaydetme
- [x] `message_page.dart` - Mesaj gönderildiğinde alıcıya FCM bildirimi gönderme (Client-side placeholder)
- [x] `firebase_messaging_service.dart` - Yeni servis dosyası oluşturma (token yönetimi, bildirim dinleme, local notifications)

### 2. Chat Veri Modeli Düzenleme
- [x] `chat_list_page.dart` - Query'yi yeni veri modeline göre güncelleme (subcollection yapısı)
- [x] `message_page.dart` - Conversation document oluşturma/güncelleme mantığını iyileştirme (unreadCount, lastMessageType, isRead)
- [ ] Firestore indexes oluşturma (composite index: participants + lastMessageTimestamp) - **Manuel Firebase Console'dan yapılmalı**

### 3. ChatListPage UI İyileştirmeleri
- [x] Modern tasarım (Material 3, renkli avatarlar, badge'ler)
- [x] Okunmamış mesaj sayısı badge'i
- [x] Son mesaj önizlemesi (metin/görsel/konum tipi + ikonlar)
- [x] Zaman formatı (bugün: saat, dün: "Dün", eski: tarih/hafta günü)
- [x] Pull-to-refresh
- [x] Boş durum illüstrasyonu
- [x] Arama butonu (AppBar actions - TODO: implement search)

### 4. MessagePage UI İyileştirmeleri
- [x] Modern mesaj balonları (gönderilen/alınan farklı stiller, tail radius)
- [x] Mesaj gruplama (avatar sadece alıcıda, gönderen için boşluk)
- [x] Tarih ayırıcıları (Bugün, Dün, 15 Ocak vb.)
- [x] Okundu/teslim edildi işaretleri (✓✓ mavi / gri)
- [x] Görsel mesaj desteği (image_picker entegrasyonu + placeholder)
- [x] Ekleme menüsü (galeri, kamera, konum, hayvan, ürün paylaşımı)
- [x] Klavye açılınca otomatik scroll en alta (animateTo)
- [x] AppBar: arama, sesli/video arama, menü (mute, block)
- [x] Yükleme skeletoni / boş durum

### 5. NotificationPage Yeniden Yazılması
- [x] Gerçek bildirim listesi (Firestore `notifications` koleksiyonundan)
- [x] Bildirim tipleri: mesaj, sipariş, kiralama, sistem, promosyon (renkli ikonlar)
- [x] Okundu/okunmadı durumu (farklı arka plan rengi + nokta)
- [x] Bildirime tıklayınca ilgili sayfaya yönlendirme (deep link - ChatList, ShopPage, PetDetailPage)
- [x] Tümünü okundu işaretle (AppBar action)
- [x] Swipe-to-delete / archive (Dismissible)

### 6. Genel İyileştirmeler
- [x] `home_page.dart` - BottomNavigationBar'e mesaj/bildirim badge'leri ekleme (real-time listeners)
- [x] `home_page.dart` - AppBar actions'a mesaj/bildirim badge'leri ekleme
- [x] SharedPreferences ile FCM token cache'leme (FirebaseMessagingService)
- [x] Hata yönetimi ve kullanıcı dostu mesajlar (SnackBar, AlertDialog)
- [x] Offline destek (Firestore persistence zaten var)

---

## 🔧 Teknik Detaylar

### FCM Bildirim Gönderme Seçenekleri:
1. **Client-side** (MessagePage içinde): `FirebaseMessagingService.sendNotificationToUser()` - placeholder implementasyonu (Cloud Function gerekli)
2. **Cloud Functions** (Önerili): `onCreate` trigger ile `messages/{chatId}/chats` yazıldığında tetiklenir
3. **Firebase Extensions**: "Send messages to FCM" extension

### Veri Modeli (Uygulanan):
```
messages (collection)
  └── {chatId} (document) - Conversation metadata
        participants: [uid1, uid2]
        lastMessage: "Merhaba"
        lastMessageType: "text" | "image" | "location" | "pet_card" | "product_card"
        lastMessageTimestamp: Timestamp
        senderUID: uid
        recipientUID: uid
        recipientFullName: string
        recipientPhotoURL: string
        unreadCount: { uid1: 0, uid2: 3 }
        updatedAt: Timestamp (serverTimestamp)
        └── chats (subcollection)
              └── {messageId} (document)
                    senderUID: uid1
                    recipientUID: uid2
                    message: "Merhaba"
                    type: "text" | "image" | "location" | "pet_card" | "product_card"
                    mediaUrl?: string
                    timestamp: Timestamp
                    isRead: boolean
                    readAt?: Timestamp
```

### notifications (collection)
```
{
  userId: string,
  title: string,
  body: string,
  type: 'message' | 'order' | 'rental' | 'system' | 'promotion',
  referenceId?: string,
  isRead: boolean,
  createdAt: Timestamp,
  readAt?: Timestamp
}
```

---

## 📋 Öncelik Sırası (Güncellenmiş)

| Öncelik | Görev | Durum | Notlar |
|---------|-------|-------|--------|
| 🔴 **Kritik** | FCM token alma/kaydetme (LoginPage) | ✅ **Tamamlandı** | FirebaseMessagingService.initialize() |
| 🔴 **Kritik** | Mesaj gönderince FCM bildirimi | ✅ **Tamamlandı** (Client-side placeholder) | Cloud Function ile production'a alınmalı |
| 🟡 **Yüksek** | ChatListPage veri modeli & UI | ✅ **Tamamlandı** | Modern UI, badge, pull-to-refresh |
| 🟡 **Yüksek** | MessagePage UI & özellikler | ✅ **Tamamlandı** | Mesaj tipleri, tarih gruplama, ekleme menüsü |
| 🟢 **Orta** | NotificationPage yeniden yazma | ✅ **Tamamlandı** | Gerçek Firestore verisi, swipe-delete |
| 🟢 **Orta** | HomePage badge entegrasyonu | ✅ **Tamamlandı** | Real-time listeners, AppBar + BottomNav |
| 🔵 **Düşük** | Görsel mesaj tam entegrasyonu | ⚠️ **Kısmi** | Storage upload placeholder (dart:io import gerekli) |
| 🔵 **Düşük** | Cloud Functions migration | ⏳ **Bekliyor** | Production için önerili |
| 🔵 **Düşük** | Firestore composite indexes | ⏳ **Manuel** | Firebase Console > Firestore > Indexes |
| 🔵 **Düşük** | Unit/Widget testleri | ⏳ **Bekliyor** | Test coverage %70+ hedefi |

---

## 🚀 Sonraki Adımlar (Önerilen)

1. **Firestore Indexes Oluşturun** (Firebase Console):
   - Collection: `messages`
   - Fields: `participants` (Array), `lastMessageTimestamp` (Descending)

2. **Cloud Functions Deploy Edin** (FCM gönderimi için):
   ```javascript
   // functions/index.js
   exports.sendMessageNotification = functions.firestore
     .document('messages/{chatId}/chats/{messageId}')
     .onCreate(async (snap, context) => {
       // FCM gönderme mantığı
     });
   ```

3. **Image Upload Tamamlayın** (message_page.dart):
   - `dart:io` import edin
   - `File(image.path)` kullanın
   - Storage upload'unu aktif edin

4. **Test Yazın**:
   - Unit test: `firebase_messaging_service_test.dart`
   - Widget test: `chat_list_page_test.dart`, `message_page_test.dart`

5. **Performans Optimizasyonu**:
   - `const` constructor kullanımı (analyze uyarıları)
   - `mounted` check'leri (zaten çoğu yerde var)

---

*Bu liste geliştirme sürecinde güncellenecektir. Son güncelleme: ${DateTime.now().toString().split('.')[0]}*
