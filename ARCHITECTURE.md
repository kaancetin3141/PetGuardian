# PetGuardian - Mimari Tablo ve Yapı Belgesi

## 📊 Genel Mimari Özeti

| Bileşen | Teknoloji | Durum | Açıklama |
|---------|-----------|-------|----------|
| **Frontend Framework** | Flutter 3.x | ✅ Aktif | Cross-platform mobil uygulama |
| **State Management** | setState / Provider | ⚠️ Basit | Gelişmiş state management (Riverpod/Bloc) öneriliyor |
| **Navigation** | Navigator 1.0 | ⚠️ Basit | GoRouter/AutoRoute geçişi öneriliyor |
| **Backend** | Firebase (BaaS) | ✅ Aktif | Auth, Firestore, Storage, Messaging |
| **Veritabanı** | Cloud Firestore | ✅ Aktif | NoSQL, real-time sync, offline support |
| **Depolama** | Firebase Storage | ✅ Aktif | Görsel/video dosyaları |
| **Kimlik Doğrulama** | Firebase Auth | ✅ Aktif | Email/Şifre, Social login |
| **Push Bildirim** | Firebase Messaging | ✅ Aktif | FCM token tabanlı |
| **Harita** | flutter_map (OSM) | ✅ Aktif | OpenStreetMap tabanlı, ücretsiz |
| **Konum** | geolocator + geocoding | ✅ Aktif | GPS + Adres çevirme |

---

## 🏗️ Modül Mimarisi (Feature-Based)

| Modül | Klasör | Sayfalar | Sorumluluk | Bağımlılıklar |
|-------|--------|----------|------------|---------------|
| **Core** | `lib/` | `main.dart`, `firebase_options.dart` | Uygulama başlatma, Firebase init | firebase_core |
| **Auth** | `lib/auth/` | `LoginPage`, `SignupPage`, `password_utils` | Kullanıcı girişi, kayıt, şifre güvenliği | firebase_auth, bcrypt |
| **Home** | `lib/pages/` | `HomePage` | Ana sayfa, keşfet, öne çıkan hayvanlar/ürünler | cloud_firestore, flutter_map |
| **Market** | `lib/pages/` | `ShopPage`, `CartPage` | Ürün listesi, sepet, ödeme akışı | cloud_firestore, firebase_storage |
| **Hayvan Detay** | `lib/pages/` | `PetDetailPage` | Hayvan profili, fotoğraflar, sahiplenme/kirala butonları | cloud_firestore, firebase_storage |
| **Kiralama/Sahiplendirme** | `lib/pages/` | `RentPage` | Sözleşme, ödeme, teslim alma süreci | cloud_firestore, firebase_auth |
| **Profil** | `lib/pages/` | `AccountPage` | Kullanıcı profili, ayarlar, favori hayvanlar | cloud_firestore, firebase_auth |
| **Bildirimler** | `lib/pages/` | `NotificationPage` | Sistem bildirimleri, mesaj, sipariş güncellemeleri | firebase_messaging, cloud_firestore |
| **Mesajlaşma** | `lib/pages/messages/` | `ChatListPage`, `MessagePage` | Gerçek zamanlı sohbet, medya paylaşımı | firebase_database, cloud_firestore |
| **Ayarlar** | `lib/settings/` | `SettingsPage` | Uygulama ayarları, tema, dil, gizlilik | shared_preferences |
| **Hayvan Yönetimi** | `lib/settings/` | `AddPetPage`, `UpdatePetInformation`, `DeletePetPage`, `ReturnPetPage`, `FavoritePetPopup`, `MapScreen` | CRUD işlemleri, konum seçimi, favori yönetimi | cloud_firestore, firebase_storage, geolocator, flutter_map |
| **Shared/Utils** | `lib/stuff/` | `image_helper`, `LoadingPage` | Görsel işleme, yükleme widget'ları | image_picker, path_provider |

---

## 🗃️ Veritabanı Şeması (Firestore Collections)

| Koleksiyon | Document ID | Alanlar | İndeksler | Güvenlik |
|------------|-------------|---------|-----------|----------|
| **users** | `uid` (Auth UID) | email, displayName, phone, photoURL, address, location(GeoPoint), favorites[], role, isVerified, fcmToken, createdAt, updatedAt | `email` (unique), `role`, `location` (geo) | Sahibi RW, Herkes R (public profil) |
| **pets** | Auto ID | ownerId, name, type, breed, age, gender, size, description, images[], location(GeoPoint), address, status, rentPrice, adoptionFee, isVaccinated, isNeutered, medicalNotes, createdAt, updatedAt | `ownerId`, `status`, `type`, `location` (geo) | Sahibi RW, Herkes R (available) |
| **products** | Auto ID | sellerId, name, category, description, price, stock, images[], brand, weight, isActive, createdAt, updatedAt | `sellerId`, `category`, `isActive` | Satıcı RW, Herkes R (active) |
| **orders** | Auto ID | buyerId, items[{productId, name, qty, price, image}], totalAmount, status, shippingAddress, paymentMethod, createdAt, updatedAt | `buyerId`, `status`, `createdAt` | Alıcı/Satıcı RW |
| **rentals** | Auto ID | petId, ownerId, renterId, type(rent/adopt), startDate, endDate, monthlyPrice, deposit, status, contractSigned, createdAt, updatedAt | `petId`, `ownerId`, `renterId`, `status` | Katılımcılar RW |
| **messages** | Auto ID | chatId, senderId, receiverId, content, type(text/image/location/pet_card/product_card), mediaUrl, isRead, createdAt | `chatId`, `createdAt`, `senderId` | Katılımcılar RW |
| **notifications** | Auto ID | userId, title, body, type, referenceId, isRead, createdAt | `userId`, `isRead`, `createdAt` | Alıcı RW |
| **shelters** | Auto ID | name, description, address, location(GeoPoint), phone, email, website, images[], operatingHours, isVerified, createdAt | `location` (geo), `isVerified` | Herkes R, Admin RW |

---

## 🔄 Veri Akış Diyagramı (Data Flow)

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│   Flutter   │────▶│  Firebase    │────▶│  Cloud          │
│   UI Layer  │     │  Auth        │     │  Firestore      │
│             │     │              │     │  (NoSQL DB)     │
└─────────────┘     └──────────────┘     └────────┬────────┘
       │                                           │
       │                    ┌──────────────────────┘
       │                    ▼
       │            ┌───────────────┐
       │            │  Firebase     │
       │            │  Storage      │
       │            │  (Images)     │
       │            └───────────────┘
       │
       ▼
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  State      │     │  Firebase    │     │  Firebase       │
│  Management │     │  Messaging   │     │  Realtime DB    │
│  (setState/ │     │  (FCM)       │     │  (Chat/Location)│
│  Provider)  │     │              │     │                 │
└─────────────┘     └──────────────┘     └─────────────────┘
```

---

## 🔐 Güvenlik Matrisi (Access Control Matrix)

| İşlem | users | pets | products | orders | rentals | messages | notifications | shelters |
|-------|-------|------|----------|--------|---------|----------|---------------|----------|
| **Guest (Oturumsuz)** | R (public) | R (available) | R (active) | - | - | - | - | R |
| **User (Kendi verisi)** | RW | RW (owner) | RW (seller) | RW (buyer) | RW (participant) | RW (participant) | RW (recipient) | R |
| **User (Başkası)** | R (public) | R (available) | R (active) | - | - | - | - | R |
| **Shelter (Barınak)** | RW (own) | RW (own) | RW (own) | RW (own) | RW (own) | RW (participant) | RW (own) | RW (own) |
| **Admin** | RW | RW | RW | RW | RW | RW | RW | RW |

**R = Read, W = Write, RW = Read & Write**

---

## 📦 Bağımlılık Grafiği (Dependency Graph)

```
PetGuardian App
├── flutter (SDK)
├── firebase_core
│   ├── firebase_auth
│   ├── cloud_firestore
│   ├── firebase_storage
│   ├── firebase_messaging
│   └── firebase_database
├── location_services
│   ├── geolocator
│   ├── geocoding
│   ├── latlong2
│   ├── permission_handler
│   └── flutter_map
├── media_handling
│   ├── image_picker
│   └── path_provider
├── networking
│   ├── http
│   └── url_launcher
├── local_storage
│   └── shared_preferences
├── security
│   └── bcrypt
├── formatting
│   └── intl
├── ui
│   └── cupertino_icons
└── dev_tools
    ├── flutter_test
    └── flutter_lints
```

---

## 🎯 State Management Durumu

| Sayfa/Widget | Mevcut Yaklaşım | Önerilen Yaklaşım | Öncelik |
|--------------|-----------------|-------------------|---------|
| `LoginPage` / `SignupPage` | setState | Provider / Riverpod | 🟡 Orta |
| `HomePage` | setState | Riverpod + FutureProvider | 🔴 Yüksek |
| `ShopPage` / `CartPage` | setState | Riverpod + StateNotifier | 🔴 Yüksek |
| `PetDetailPage` | setState | Riverpod + StreamProvider | 🔴 Yüksek |
| `ChatListPage` / `MessagePage` | setState | Riverpod + StreamProvider | 🔴 Yüksek |
| `AddPetPage` / `UpdatePetInformation` | setState | Riverpod + StateNotifier | 🟡 Orta |
| `MapScreen` | setState | Riverpod | 🟢 Düşük |
| `AccountPage` / `SettingsPage` | setState | Provider | 🟢 Düşük |

---

## 🧪 Test Mimarisi

| Test Türü | Araçlar | Kapsam | Durum |
|-----------|---------|--------|-------|
| **Unit Test** | `flutter_test`, `mockito` | Utils, helpers, business logic | ❌ Yok |
| **Widget Test** | `flutter_test` | Sayfa widget'ları, form validasyonu | ❌ Yok |
| **Integration Test** | `integration_test` | Kullanıcı akışları (login→home→pet detail) | ❌ Yok |
| **Golden Test** | `golden_toolkit` | UI regresyon testleri | ❌ Yok |

---

## 📱 Ekran Boyutu ve Yönlendirme Stratejisi

| Breakpoint | Genişlik | Layout | Navigation |
|------------|----------|--------|------------|
| **Phone** | < 600dp | Single column, BottomNav | Navigator.push |
| **Tablet** | 600-900dp | Two column (Master-Detail) | Navigator.push / GoRouter |
| **Desktop/Web** | > 900dp | Three column (Sidebar-Content-Detail) | GoRouter (URL-based) |

---

## 🚀 CI/CD Pipeline (Önerilen)

```yaml
# .github/workflows/ci.yml
stages:
  1. analyze:     flutter analyze --fatal-infos
  2. format:      dart format --set-exit-if-changed .
  3. test:        flutter test --coverage
  4. build_android: flutter build apk --release
  5. build_ios:   flutter build ios --release --no-codesign
  6. deploy_firebase: firebase deploy --only firestore,storage,functions
```

---

## 📈 Performans Metrikleri (Hedefler)

| Metrik | Hedef | Ölçüm Araçı |
|--------|-------|-------------|
| **App Startup (Cold)** | < 3 saniye | Flutter DevTools, Firebase Performance |
| **Frame Rate** | 60 FPS (120 FPS hedef) | Flutter DevTools Performance Overlay |
| **Memory Usage** | < 150 MB | DevTools Memory Profiler |
| **Firestore Read/Write** | < 100ms p99 | Firebase Console Monitoring |
| **Image Load Time** | < 2 saniye | Network Profiler |
| **Offline Sync** | < 5 saniye | Manual testing |

---

## 🔧 Konfigürasyon Dosyaları

| Dosya | Açıklama | Ortam |
|-------|----------|-------|
| `pubspec.yaml` | Bağımlılıklar, assets, versiyon | Tüm ortamlar |
| `analysis_options.yaml` | Lint kuralları | Development |
| `firebase_options.dart` | Firebase config (auto-generated) | Tüm ortamlar |
| `firestore.rules` | Güvenlik kuralları | Production/Staging |
| `storage.rules` | Storage güvenlik kuralları | Production/Staging |
| `SECURITY_RULES.md` | Güvenlik dokümantasyonu | Development |
| `CI_WORKFLOW.yml` | GitHub Actions CI/CD | CI/CD |

---

## 📋 Geliştirme Kontrol Listesi (Definition of Done)

### Kod Kalitesi
- [ ] `flutter analyze` hatasız geçiyor
- [ ] `dart format .` uygulanmış
- [ ] Lint kuralları (flutter_lints) takip ediliyor
- [ ] Meaningful commit mesajları (Conventional Commits)

### Test
- [ ] Unit testler yazılmış (%70+ coverage hedefi)
- [ ] Widget testler kritik akışlar için var
- [ ] Manual test (device/emulator) yapılmış

### Güvenlik
- [ ] Firestore rules güncellenmiş ve test edilmiş
- [ ] Storage rules güncellenmiş
- [ ] Hassas veri (API key, token) kodda yok
- [ ] Input validation (client + server/Firestore rules)

### Performans
- [ ] Gereksiz rebuild'ler önlenmiş (const, Provider.select)
- [ ] Görseller optimize edilmiş (WebP, boyutlandırma)
- [ ] Lazy loading uygulanmış (ListView.builder, pagination)

### Dokümantasyon
- [ ] README güncellenmiş
- [ ] SKILLS.md / ARCHITECTURE.md güncellenmiş
- [ ] Kod içinde karmaşık mantık için yorumlar var
- [ ] API/Firestore şema değişiklikleri belgelenmiş

---

## 🗓️ Sprint Planlama Önerisi (2 Haftalık Sprintler)

| Sprint | Odak Alanı | Teslim Edilebilirler |
|--------|------------|----------------------|
| **Sprint 1** | Temel Altyapı & Auth | Login/Signup, Firebase setup, Temel navigation |
| **Sprint 2** | Ana Sayfa & Hayvan Listesi | HomePage, Pet listesi, Arama/Filtre, Harita entegrasyonu |
| **Sprint 3** | Hayvan Detay & Sahiplendirme | PetDetailPage, RentPage, Sözleşme akışı |
| **Sprint 4** | Market & Sepet | ShopPage, CartPage, Ödeme entegrasyonu (iyzico/Stripe) |
| **Sprint 5** | Mesajlaşma & Bildirimler | ChatListPage, MessagePage, FCM push notifications |
| **Sprint 6** | Profil & Ayarlar | AccountPage, SettingsPage, Hayvan yönetimi CRUD |
| **Sprint 7** | State Management & Refactor | Riverpod/Bloc geçişi, Performance optimizasyonu |
| **Sprint 8** | Test & Polish | Unit/Widget testler, Golden testler, Bug fixes |
| **Sprint 9** | Release & Deploy | Play Store / App Store deploy, Monitoring setup |

---

*Bu belge proje mimarisini tablo formatında özetlemek için oluşturulmuştur. Yeni modüller eklendikçe veya mimari değiştikçe güncellenmelidir.*