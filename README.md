# 🍮 Jöle Shapeshifter (Jelly Shapeshifter)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg?logo=flutter)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2.svg?logo=dart)](https://dart.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-brightgreen.svg)]()
[![Performance](https://img.shields.io/badge/FPS-60_Smooth-FF7043.svg)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Jöle Shapeshifter**, Flutter'ın güçlü Custom Painter ve Canvas API'leri kullanılarak sıfırdan geliştirilmiş, yüksek tempolu ve akıcı bir **şekil değiştirme (shapeshifter) mobil arcade/hyper-casual oyunudur**.

Oyuncu, engellerle dolu parkurda sevimli jöle karakterini formdan forma sokarak (kare, yassı, normal) hayatta kalmaya ve en yüksek skora ulaşmaya çalışır.

---

## 🎮 Oynanış & Temel Mekanikler

* 🔄 **Dinamik Şekil Değiştirme:**
  * **Kare Formu (Kare Tüneller):** Dar ve yüksek boşluklardan geçmek için karakter dikleşir ve sertleşir.
  * **Yassı Formu (Alçak Duvarlar):** Alçak engellerin altından kayarak geçmek için jöle zemine yayılır.
  * **Serbest Form:** Hızlı toparlanma ve engeller arası akıcı geçiş.
* 👀 **Canlı Duygu & Göz Animasyonları:** Karakter durumuna göre değişen tepkisel yüz ifadeleri:
  * `Normal`, `Flat` (Yassılaşma), `Panic` (Engele yaklaşma), `Star` (Kombo/Kutlama), `Fever` (Ateşli mod), `Dead` (Oyun bitti).
* 💥 **Jel & Yay Fiziği (Squash & Stretch):** Gerçekçi elastik jöle salınımı, arkasında bıraktığı dinamik parçacık izleri ve neon parıltı efektleri.
* ⚡ **Kombo & Çarpan Sistemi:** Hata yapmadan seri engelleri geçtikçe yükselen kombo çarpanı ve "Fever Mode" akışı.
* 🎨 **Kostüm & Skin Mağazası:** Toplanan puan ve elmaslarla açılabilen özel renk paletlerine ve neon ışıltılara sahip jöle kostümleri.
* 📳 **Haptic Feedback & Sürükleyici Mod:** Android/iOS dokunsal titreşim geri bildirimleri ve tam ekran (immersive sticky) oyun deneyimi.

---

## 🛠️ Teknik Altyapı & Mimari

Oyun, üçüncü parti ağır bir oyun motoru (Unity, Unreal) yerine **saf Flutter & Dart Canvas** üzerinde 60 FPS kararlılıkla çalışacak şekilde optimize edilmiştir:
* **Custom Painter:** `CustomPainter` ve `TickerProvider` ile sıfır gecikmeli procedural render pipeline.
* **Matematiksel Fizik Döngüsü:** Sinüs dalgaları, yay katsayıları (damping/elasticity) ve dinamik `lerpDouble` interpolasyonları.
* **Hafıza Optimizasyonu:** Çöp toplayıcıyı (GC) yormamak adına dinamik obje havuzlama (object pooling mantığı).

---

## 📱 Ekran Görüntüleri / Önizleme

> *Uygulamanın hazır derlenmiş APK dosyası [Releases](https://github.com/siladgn/jole_game/releases) bölümünden veya repo içindeki test paketinden indirilebilir.*

| Ana Menü & Kostümler | Oyun İçi Aksiyon | Şekil Değiştirme |
| :---: | :---: | :---: |
| *(Önizleme Eklenecek)* | *(Önizleme Eklenecek)* | *(Önizleme Eklenecek)* |

---

## 🚀 Projeyi Çalıştırma

### Gereksinimler
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.8 veya üzeri)
* Android Studio / VS Code
* Bir Android/iOS cihaz veya Emülatör

### Kurulum Adımları
```bash
# Depoyu klonlayın
git clone https://github.com/siladgn/jole_game.git
cd jole_game

# Paketleri yükleyin
flutter pub get

# Cihazınızda çalıştırın
flutter run
```

### APK Olarak Derleme
```bash
flutter build apk --release
```
Oluşan APK: `build/app/outputs/flutter-apk/app-release.apk`

---

## 📄 Lisans

Bu proje [MIT Lisansı](LICENSE) ile korunmaktadır.
