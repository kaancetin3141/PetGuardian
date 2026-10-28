# PetGuardian — Güvenlik ve Sızma Testi Raporu

Tarih: 2026-10-27 · Kapsam: `firestore.rules`, `storage.rules`, `lib/` istemci kodu
Yöntem: kod denetimi + Firestore emülatörü üzerinde adversaryal senaryolar (`@firebase/rules-unit-testing`)
Güncelleme: 2026-10-28 — kural seti 88 → **110 assertion**'a çıktı (`reports` + yeni `applications` koleksiyonu); tümü emülatörde yeşil.

## Sonuç

**VERDICT: PASS (8/8 bulgu giderildi)** — 110/110 kural testi emülatörde doğrulandı,
`flutter analyze --fatal-infos --fatal-warnings` temiz, 65/65 Dart testi geçti,
web derlemesi başarılı.

## Giderilen Bulgular

| # | Bulgu | Severity | Kanıt |
|---|---|---|---|
| 1 | `users.list` açıktı: herhangi bir hesap tek sorguda tüm e-posta/telefon/IP'leri toplayabilirdi | HIGH | Kuralda `list` kaldırıldı; test: `user cannot list all profiles (PII harvest)` PASS |
| 2 | FCM token `users/{uid}` profilindeydi (herkes okuyabilir); token sızdırırsa saldıran bu kullanıcıya bildirim gönderebilir | HIGH | Token `users/{uid}/private/fcm` sahiplik alt koleksiyonuna taşındı; testler: foreign read/write/unauth read PASS |
| 3 | `orders` durumu müşteri tarafından `delivered`/`paid` olarak yükseltilebilirdi (kendi kendine onay) | HIGH | Update yalnızca `isAdmin()`; test: `customer cannot change their own order status` + `admin can update` PASS |
| 4 | `messages/{id}/chats` yazımında katılımcı doğrulaması yoktu: herkes var olan sohbete sahte mesaj enjekte edebilir, var olmayan yol üzerinden iki kişi arasında konuşma taklidi yapabilirdi | HIGH | `isParticipant()` + `participants == conversation().data.participants` zorunlu; 5 enjeksiyon testi PASS |
| 5 | `ip` alanı istemcide hesap açılışında üçüncü taraf servisten toplanıp saklanıyordu (KVKK/GDPR gereksiz veri + üçüncü tarafa sızıntı) | MEDIUM | `signup_page.dart`'tan `ip` + ipify isteği silindi; kuralda create/update'te yasak; testler PASS |
| 6 | `storage.rules` istemcinin yazdığı hiçbir yolu (`profile_images/`, `chat_images/`, `pets_images/`) kapsamıyordu; ayrıca `/users/**` yazımına izin veriyordu | MEDIUM | Kurallar gerçek yollarla yeniden yazıldı + 10MB/görsel tipi sınırı; chat medyası yalnızca katılımcıya |
| 7 | Chat mesaj yazımı kök düzeyde dosya adıyla Storage'a yüklüyordu (kural dışı) ve `sendEmailVerification` hatası hesabı "kayıt başarısız" gösteriyordu | MEDIUM | `pets_images/` altına taşındı; doğrulama e-postası ayrı try/catch |
| 8 | Composite index eksik: production'da chat listesi ve bildirim sorguları `failed-precondition` ile düşerdi | LOW | `firestore.indexes.json` eklendi ve `firebase.json`'a bağlandı |

## Kalan Riskler (bilinçli kabul / sonraki iş)

- **Profil `get` PII Exposure (MEDIUM)**: Firestore alan bazlı okuma engellenemez; her oturum açmış kullanıcı bir profilin e-posta/telefonunu `get()` ile okuyabilir. Chat ekranları bu alanlara ihtiyaç duyuyor. Alternatif: sunucu tarafında (Cloud Function) isim/.avatar gölge koleksiyonu — mimari değişiklik gerektirir.
- **FCM push teslimi yok (MEDIUM, işlevsel)**: Güvenlik gereği istemci artık token okuyamaz; bildirim gönderimi Firestore trigger'lı Cloud Function ile kurulmalı (`sendNotificationToUser` yer tutucuyu logluyor).
- **Üretim index dağıtımı**: `firebase deploy --only firestore:indexes` çalıştırılmalı; emülatör index zorunluluğu uygulamaz.
- **Storage.rules emülatör testi yok (LOW)**: `rules-unit-testing` Firestore'a odaklı; storage kuralları için Firebase Emulator Suite + Storage SDK ile ayrı senaryo gerekir.
- **Android APK derlemesi (environment)**: `firebase_core:compileDebugKotlin` "Unresolved reference 'android'" + disk alanı yetersizliği nedeniyle bloke; iOS yalnızca statik denetim yapıldı (Windows'ta derlenemez).

## applications koleksiyonu (2026-10-28 ek)

Sahiplendirme başvuruları (`applications/<petId>_<applicantUid>`, tek başvuru/kullanıcı/pet yapısal olarak):

- **create**: yalnızca imzalı kullanıcı; `applicantUID == request.auth.uid`; `ownerUID != applicantUID` (kendi ilanına başvuru yok); mesaj 1–1000 karakter; durum zorunlu `pending`.
- **read**: yalnızca başvuru sahibi, ilan sahibi veya admin — başkalarının başvuruları sayılamaz.
- **update**: yalnızca `pending` durumundan geçiş (owner: `approved`/`declined`; başvuran: `withdrawn`; admin: her ikisi) ve yalnızca triage anahtarları (`status`, `resolvedAt`, `resolvedBy`, `moderatorNote`).
- **delete**: tüm istemciler için reddedildi (denetim kaydı).
- Test: 22 assertion — sahte başvuran, kendi ilanına başvuru, boş/uzun mesaj, doğrudan `approved` açılışı, yabancı okuma, başvuranın onay/red denemesi, tamamlanmış kaydın yeniden değişimi, mesaj kurcalama, yabancı triage, silme ve admin okuma.
