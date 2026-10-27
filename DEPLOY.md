# PetGuardian — Yayına Alma (EC2 Ubuntu + Firebase)

Bu uygulamanın sunucu tarafı **yok**: backend Firebase (Auth/Firestore/Storage/FCM).
EC2 `t3.micro` (Ubuntu) yalnızca Flutter web build'ini statik sunar — Nginx ile.
Ücretsiz kalır: Firebase Spark kotası + EC2'nin kendi ücretsiz katmanı.

## 0. Gerekenler

- EC2 instance (Ubuntu 22.04/24.04), SSH anahtarınız (`-KeyFile ...pem`)
- AWS Security Group: inbound **22** (yalnızca kendi IP'niz), **80**, **443**
- Firebase projesi `petguardian-0000` üzerinde admin (Firebase Console girişi)

## 1. Sunucu kurulumu (bir kez)

Sunucuda:

```bash
# projeyi sunucuya kopyalamaya gerek yok; betikleri tek seferlik aktarın
bash setup-server.sh
```

Kurduğunda: nginx + site konfigürasyonu, 1G swap (t3.micro 1GB RAM için OOM
koruması), ufw (22/80/443), atomik release dizin düzeni.

## 2. Firebase production hazırlığı (bir kez — localhost'tan)

Kurallar/index'ler henüz **yalnızca** test emülatöründe doğrulandı; production'a
gönderilmeleri şart (yoksa production'da eski açık kurallar geçerli kalır):

```powershell
cd C:\Users\deli\Desktop\denemeler\PetGuardian-main
npx firebase-tools login          # bir kez
npx firebase-tools deploy --only firestore:rules,firestore:indexes,storage
```

Ayrıca Firebase Console'da:

1. **Authentication → Settings → Authorized domains** alanına sunucunuzun
   alan adını ekleyin (ham IP ile e-posta/şifre girişi **engellenir**;
   geçici test için `localhost` zaten listede). Alan adınız yoksa 3. adıma bakın.
2. Authentication → Sign-in method → **Email/Password açık** olmalı.
3. **Firestore indexes** deploy'u `failed-precondition` hatalarını çözer
   (chat listesi + bildirim sorguları).

## 3. Alan adı (domain) — önerilir

Firebase Auth production'da yalnızca kayıtlı alan adlarından girişe izin verir.
Seçenekler:

- Kendi alan adınız: DNS A kaydı → EC2 public IP. Sonra `certbot --nginx -d alan.com`
- Ücretsiz geçici: `nip.io` gibi servisler (`ec2-ip.nip.io`) — DNS'siz çalışır;
  Firebase Authorized domains'e eklenir, Let's Encrypt de kabul eder.

## 4. Yayına alma (her sürümde)

Bilgisayarda (proje kökünden):

```powershell
.\deploy\publish.ps1 -Host <ec2-public-dns> -User ubuntu -KeyFile C:\path\key.pem
```

Adımlar: build → scp ile `/tmp/petguardian-next` → `server-deploy.sh`
(anashtarı atomik değiştirir, nginx reload, 127.0.0.1 smoke check, son 5
release'ı saklar). Yükleme yarıda kesilse bile eski sürüm canlı kalır.

### Manuel alternatif (scp bilenler için)

```powershell
& flutter build web --release
scp -r build\web\* ubuntu@<host>:/tmp/petguardian-next/
ssh ubuntu@<host> 'bash -s' < deploy\server-deploy.sh
```

## 5. HTTPS

Sunucuda bir kez (alan adı DNS'te işaretliyken):

```bash
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d alan-adiniz.com
# 80/443 Security Group açık olmalı; yenileme otomatiktir
```

## 6. Doğrulama listesi (her yayın sonrası)

- [ ] `http://<host>/` 200 + PetGuardian başlığı
- [ ] Tarayıcı konsolunda Firebase hatası yok (`Firebase.initializeApp`)
- [ ] Yeni sekmede kayıt ol + giriş yap (Authorized domain doğruysa)
- [ ] Pet listesi + detay + favoriler
- [ ] Mesajlaşma akışı (sohbet listesi → mesaj gönder)
- [ ] Sepet → sipariş oluştur
- [ ] Kırık asset yok (404) — network sekmesi temiz

## 7. Rollback

Sunucuda:

```bash
ls -1dt /var/www/petguardian/releases/*     # son 5 release
sudo ln -sfn /var/www/petguardian/releases/<eski-ts> /var/www/petguardian/current
sudo systemctl reload nginx
```

## 8. Bu makineye sığmayanlar (ayrı işler)

- **FCM push gönderimi**: sunucu artık var — Cloud Functions Blaze yerine bu
  EC2'de ücretsiz bir cron/systemd servisi FCM HTTP v1 API ile push atabilir
  (servis hesabı JSON'u secret olarak). Backend yok dediğimize bakmayın:
  sadece bildirim kuyruğu işler.
- **Android APK**: Play Store yayını ayrı (imzalama + mağaza hesabı).
  CI'da analyze/test/web zaten yeşil.
- **iOS**: macOS + Xcode + Apple Developer hesabı şart.

## Maliyet özeti

| Kalem | Durum |
|---|---|
| Firebase Spark (Auth 10K/ay, Firestore 50K okuma/gün, Storage 5GB) | $0 — bu ölçek yeterli |
| EC2 t3.micro | AWS free tier 12 ay ücretsiz (sonrası ~$8/ay; instance'ınız zaten var) |
| Alan adı | ~$10/yıl (nip.io ile $0 geçici) |
| HTTPS / Let's Encrypt | $0 |
| CI (GitHub Actions) | $0 |
