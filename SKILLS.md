# PetGuardian - Geliştirici Becerileri ve Mimarisi

## 🎯 Proje Özeti
PetGuardian, evcil hayvan sahiplerinin ve hayvan sevenlerin buluştuğu, hayvan kiralama/sahiplenme, ürün satışı, mesajlaşma ve konum tabanlı hizmetler sunan bir Flutter mobil uygulamasıdır.

---

## 🛠️ Teknoloji Yığını (Tech Stack)

### Frontend (Flutter)
| Kategori | Teknoloji | Versiyon | Açıklama |
|----------|-----------|----------|----------|
| Framework | Flutter | 3.x | Cross-platform mobil geliştirme |
| Language | Dart | 3.x | Tip güvenli, modern dil |
| State Management | setState / Provider* | - | Basit state yönetimi |
| Navigation | Navigator 2.0 / GoRouter* | - | Sayfa yönlendirme |

### Backend & Services (Firebase)
| Servis | Kullanım Alanı |
|--------|----------------|
| **Firebase Auth** | Kullanıcı kimlik doğrulama (Email/Şifre, Google, Apple) |
| **Cloud Firestore** | NoSQL veritabanı (Kullanıcılar, Hayvanlar, Ürünler, Mesajlar, Siparişler) |
| **Firebase Storage** | Görsel dosyalar (Hayvan fotoğrafları, Ürün resimleri, Profil fotoğrafları) |
| **Firebase Messaging** | Push bildirimleri (Mesajlar, Sipariş güncellemeleri) |
| **Firebase Database (Realtime)** | Anlık mesajlaşma, konum takibi |
| **Firebase Core** | Firebase başlatma ve yapılandırma |

### Harita & Konum
| Paket | Açıklama |
|-------|----------|
| `flutter_map` | OpenStreetMap tabanlı harita görüntüleme |
| `geolocator` | Cihaz konumu alma |
| `geocoding` | Adres ↔ Koordinat dönüşümü |
| `latlong2` | Koordinat işlemleri |
| `permission_handler` | Konum izinleri yönetimi |

### Diğer Kütüphaneler
| Paket | Açıklama |
|-------|----------|
| `http` | REST API çağrıları |
| `image_picker` | Galeri/Kameradan fotoğraf seçimi |
| `url_launcher` | Harici linkler açma (telefon, e-posta, web) |
| `shared_preferences` | Yerel depolama (token, ayarlar) |
| `path_provider` | Dosya sistemi erişimi |
| `bcrypt` | Şifre hashleme |
| `intl` | Tarih/sayı formatlama, lokalizasyon |
| `flutter_lints` | Kod kalitesi (linting) |

---

## 📁 Proje Mimarisi (Clean Architecture Yaklaşımı)

```
lib/
├── main.dart                 # Uygulama giriş noktası, Firebase init
├── firebase_options.dart     # Firebase platform yapılandırması
│
├── auth/                     # Kimlik Doğrulama Modülü
│   ├── login_page.dart        # Giriş sayfası
│   ├── signup_page.dart       # Kayıt sayfası
│   └── password_utils.dart   # Şifre hash/doğrulama yardımcıları
│
├── pages/                    # Ana Sayfa Modülleri (Feature-based)
│   ├── home_page.dart         # Ana sayfa (Keşfet, öne çıkanlar)
│   ├── shop_page.dart         # Market/Ürün listesi
│   ├── cart_page.dart         # Sepet ve ödeme
│   ├── pet_detail_page.dart    # Hayvan detay sayfası
│   ├── rent_page.dart         # Kiralama/sahiplendirme süreci
│   ├── account_page.dart      # Kullanıcı profili
│   ├── notification_page.dart # Bildirimler
│   └── messages/             # Mesajlaşma Alt Modülü
│       ├── chat_list_page.dart # Sohbet listesi
│       └── message_page.dart  # Tekil sohbet ekranı
│
├── settings/                 # Ayarlar ve Hayvan Yönetimi
│   ├── settings_page.dart     # Genel ayarlar
│   ├── add_pet_page.dart       # Hayvan ekleme
│   ├── update_pet_information.dart # Hayvan bilgisi güncelleme
│   ├── delete_pet_page.dart    # Hayvan silme
│   ├── return_pet_page.dart    # Hayvan iade/geri verme
│   ├── favorite_pet_popup.dart # Favori hayvan popup'ı
│   └── map_screen.dart        # Harita konum seçimi
│
└── stuff/                    # Yardımcı/Ortak Kodlar (Shared)
    ├── image_helper.dart     # Görsel işleme yardımcıları
    └── loading_page.dart      # Yükleme ekranı widget'ı
```

---

## 🗄️ Veri Modeli (Firestore Collections)

### 1. `users` Koleksiyonu
```dart
{
  uid: string,                    // Firebase Auth UID
  email: string,
  displayName: string,
  phoneNumber?: string,
  photoURL?: string,
  address?: string,
  location?: GeoPoint,            // Konum (lat, lng)
  createdAt: Timestamp,
  updatedAt: Timestamp,
  favorites: string[],            // Favori hayvan/ürün ID'leri
  role: 'user' | 'admin' | 'shelter',  // Kullanıcı rolü
  isVerified: boolean,
  fcmToken?: string               // Push bildirim token'ı
}
```

### 2. `pets` Koleksiyonu
```dart
{
  id: string,                     // Document ID
  ownerId: string,                // users.uid referansı
  name: string,
  type: 'dog' | 'cat' | 'bird' | 'other',
  breed?: string,
  age: int,                       // Ay cinsinden
  gender: 'male' | 'female',
  size: 'small' | 'medium' | 'large',
  description: string,
  images: string[],               // Storage URL'leri
  location: GeoPoint,             // Hayvanın konumu
  address: string,
  status: 'available' | 'rented' | 'adopted' | 'returned',
  rentPrice?: double,             // Aylık kira bedeli (TL)
  adoptionFee?: double,           // Sahiplendirme bedeli
  isVaccinated: boolean,
  isNeutered: boolean,
  medicalNotes?: string,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 3. `products` Koleksiyonu (Market)
```dart
{
  id: string,
  sellerId: string,               // users.uid
  name: string,
  category: 'food' | 'toy' | 'health' | 'accessory' | 'other',
  description: string,
  price: double,
  stock: int,
  images: string[],
  brand?: string,
  weight?: string,                // Örn: "2kg", "500g"
  isActive: boolean,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 4. `orders` Koleksiyonu
```dart
{
  id: string,
  buyerId: string,
  items: [
    {
      productId: string,
      productName: string,
      quantity: int,
      price: double,
      image: string
    }
  ],
  totalAmount: double,
  status: 'pending' | 'confirmed' | 'shipped' | 'delivered' | 'cancelled',
  shippingAddress: string,
  paymentMethod: 'cash' | 'card' | 'online',
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 5. `rentals` Koleksiyonu (Kiralama/Sahiplendirme)
```dart
{
  id: string,
  petId: string,                  // pets.id
  ownerId: string,                // Hayvan sahibi
  renterId: string,               // Kiralayan/Sahiplenen
  type: 'rent' | 'adopt',         // Kiralama mı sahiplendirme mi
  startDate: Timestamp,
  endDate?: Timestamp,            // Kiralama için bitiş tarihi
  monthlyPrice: double,
  deposit?: double,               // Depozito
  status: 'pending' | 'active' | 'completed' | 'cancelled' | 'returned',
  contractSigned: boolean,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 6. `messages` Koleksiyonu (Realtime Database veya Firestore)
```dart
{
  id: string,
  chatId: string,                 // Benzersiz sohbet ID'si (user1_user2)
  senderId: string,
  receiverId: string,
  content: string,
  type: 'text' | 'image' | 'location' | 'pet_card' | 'product_card',
  mediaUrl?: string,
  isRead: boolean,
  createdAt: Timestamp
}
```

### 7. `notifications` Koleksiyonu
```dart
{
  id: string,
  userId: string,                 // Alıcı kullanıcı
  title: string,
  body: string,
  type: 'message' | 'order' | 'rental' | 'system' | 'promotion',
  referenceId?: string,           // İlgili order/pet/chat ID
  isRead: boolean,
  createdAt: Timestamp
}
```

### 8. `shelters` Koleksiyonu (Hayvan Barınakları)
```dart
{
  id: string,
  name: string,
  description: string,
  address: string,
  location: GeoPoint,
  phone: string,
  email?: string,
  website?: string,
  images: string[],
  operatingHours: string,
  isVerified: boolean,
  createdAt: Timestamp
}
```

---

## 🔐 Güvenlik Kuralları (Firestore Rules Özeti)

```javascript
// Kullanıcılar kendi verilerini okuyup yazabilir
match /users/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
  allow read: if request.auth != null; // Diğer kullanıcılar profil okuyabilir
}

// Hayvanlar: Sahibi yazabilir, herkes okuyabilir (available olanlar)
match /pets/{petId} {
  allow read: if resource.data.status == 'available' || request.auth != null;
  allow create: if request.auth != null;
  allow update, delete: if request.auth != null && request.auth.uid == resource.data.ownerId;
}

// Siparişler: Alıcı ve satıcı erişebilir
match /orders/{orderId} {
  allow read, write: if request.auth != null && 
    (request.auth.uid == resource.data.buyerId || 
     request.auth.uid in resource.data.items.sellerId);
}

// Mesajlar: Sohbet katılımcıları erişebilir
match /messages/{messageId} {
  allow read, write: if request.auth != null && 
    (request.auth.uid == resource.data.senderId || 
     request.auth.uid == resource.data.receiverId);
}
```

---

## 🎨 UI/UX Tasarım Prensipleri

| Prensip | Açıklama |
|---------|----------|
| **Material Design 3** | Modern Flutter tasarım dili |
| **Responsive** | Farklı ekran boyutlarına uyum (phone, tablet) |
| **Accessibility** | Semantik etiketler, kontrast oranları |
| **Loading States** | Tüm async işlemlerde loading indicator |
| **Error Handling** | Kullanıcı dostu hata mesajları, retry mekanizması |
| **Offline Support** | Firestore offline persistence etkin |

---

## 📱 Platform Desteği

| Platform | Durum | Notlar |
|----------|-------|--------|
| Android | ✅ Destekleniyor | Min SDK 21+ |
| iOS | ✅ Destekleniyor | Min iOS 12+ |
| Web | ⚠️ Kısmi | Firebase Auth/Storage sınırlamaları |
| Windows | ⚠️ Kısmi | Harita/konum özellikleri sınırlı |
| macOS | ⚠️ Kısmi | Harita/konum özellikleri sınırlı |
| Linux | ❌ Desteklenmiyor | - |

---

## 🚀 Geliştirme Komutları

```bash
# Bağımlılıkları yükle
flutter pub get

# Kod analizi (linting)
flutter analyze

# Testleri çalıştır
flutter test

# Debug build (Android)
flutter run

# Release build (Android)
flutter build apk --release
flutter build appbundle --release

# Release build (iOS)
flutter build ios --release

# Firebase deploy (Rules, Functions)
firebase deploy

# Kod formatlama
dart format .
```

---

## 📋 Geliştirme Standartları

### Naming Conventions
- **Dosyalar**: `snake_case.dart` (örn: `pet_detail_page.dart`)
- **Sınıflar**: `PascalCase` (örn: `PetDetailPage`)
- **Değişkenler/Fonksiyonlar**: `camelCase` (örn: `fetchPetDetails()`)
- **Sabitler**: `SCREAMING_SNAKE_CASE` (örn: `MAX_IMAGE_SIZE`)
- **Private**: `_` prefix (örn: `_petName`)

### Git Commit Mesajları
```
feat: yeni özellik eklendi
fix: hata düzeltildi
refactor: kod yeniden düzenlendi (özellik değişmedi)
style: formatlama, noktalama vb.
docs: dokümantasyon güncellendi
test: test eklendi/güncellendi
chore: build süreçleri, bağımlılıklar
```

### Branch Stratejisi
- `main` - Production ready kod
- `develop` - Geliştirme dalı
- `feature/*` - Yeni özellikler
- `bugfix/*` - Hata düzeltmeleri
- `hotfix/*` - Acil production düzeltmeleri

---

## 🔮 Gelecek Geliştirme Alanları (Roadmap)

### v1.1 - Kullanıcı Deneyimi
- [ ] Karanlık mod (Dark theme)
- [ ] Çoklu dil desteği (TR/EN)
- [ ] Bildirim tercihleri sayfası
- [ ] Arama ve filtreleme iyileştirmeleri

### v1.2 - Sosyal Özellikler
- [ ] Kullanıcı değerlendirme/puanlama sistemi
- [ ] Hayvan hikayeleri (Story/Reels benzeri)
- [ ] Topluluk forum/gruplar
- [ ] Etkinlik takvimi (Sahiplendirme günleri)

### v1.3 - Gelişmiş Özellikler
- [ ] AI tabanlı hayvan öneri motoru
- [ ] Veteriner randevu sistemi
- [ ] Sağlık takibi (aşı, ilaç hatırlatıcı)
- [ ] QR kod ile hayvan kimlik kartı

### v2.0 - Platform Genişletme
- [ ] Web tam desteği
- [ ] Admin paneli (Web)
- [ ] Barınak yönetim paneli
- [ ] API dokümantasyonu (Swagger)

---

## 📞 İletişim ve Kaynaklar

- **Firebase Console**: https://console.firebase.google.com/project/petguardian
- **Flutter Dokümantasyon**: https://docs.flutter.dev
- **Firebase Flutter Docs**: https://firebase.flutter.dev
- **OpenStreetMap**: https://www.openstreetmap.org (Harita kaynağı)

---

*Bu dosya proje mimarisini ve geliştirme standartlarını belgelemek için oluşturulmuştur. Proje büyüdükçe güncellenmelidir.*