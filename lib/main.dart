import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const JoleGameApp());
}

class JoleGameApp extends StatelessWidget {
  const JoleGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jöle Shapeshifter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090514),
      ),
      home: const GameScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Kostüm Modeli (Skins)
// ─────────────────────────────────────────────────────────────
class JellySkin {
  final String name;
  final Color primaryColor;
  final Color glowColor;
  final int cost;
  bool isUnlocked;

  JellySkin({
    required this.name,
    required this.primaryColor,
    required this.glowColor,
    required this.cost,
    this.isUnlocked = false,
  });
}

enum ObstacleType {
  narrowTunnel, // Dar Tünel: Kare formda ortadan geçilir
  lowWall,      // Alçak Duvar: Yassı formda altından kayılır
}

enum EyeExpression { normal, flat, panic, star, dead, fever }

// ─────────────────────────────────────────────────────────────
// Engel Sınıfı
// ─────────────────────────────────────────────────────────────
class Obstacle {
  final ObstacleType type;
  double y;
  bool scored;
  final double gapWidth;
  final double wallHeight;
  double gapCenterX; // Deliğin X koordinat merkezi

  // Hareketli engel özellikleri
  bool isMoving;
  double oscillationSpeed;
  double oscillationRange;
  double phase;
  double xOffset = 0.0;

  Obstacle({
    required this.type,
    required this.y,
    this.scored = false,
    required this.gapWidth,
    required this.wallHeight,
    this.gapCenterX = 0.0,
    this.isMoving = false,
    this.oscillationSpeed = 0.03,
    this.oscillationRange = 50.0,
    this.phase = 0.0,
  });
}

// ─────────────────────────────────────────────────────────────
// Kristaller (Gems)
// ─────────────────────────────────────────────────────────────
class GameGem {
  double x;
  double y;
  bool collected;
  final double size = 26.0;

  GameGem({
    required this.x,
    required this.y,
    this.collected = false,
  });
}

// ─────────────────────────────────────────────────────────────
// Efekt Sınıfları
// ─────────────────────────────────────────────────────────────
class JellyTrail {
  final double x;
  final double y;
  final double width;
  final double height;
  final Color color;
  double opacity;

  JellyTrail({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
    required this.opacity,
  });
}

class SpeedLine {
  double x;
  double y;
  double length;
  double speed;

  SpeedLine({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
  });
}

enum GameState { menu, playing, gameOver }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // ── Oyun Durumları ──
  GameState _gameState = GameState.menu;
  int _score = 0;
  int _highScore = 0;
  int _collectedGemsCount = 0; // Bu tur toplanan yıldızlar
  int _totalGems = 0;          // Dükkanda harcanacak toplam yıldız birikimi
  double _screenShakeIntensity = 0.0;

  // ── Yavaş Çekim (Slow-Motion) & Near Miss ──
  double _timeDilation = 1.0;
  double _slowMotionDuration = 0.0;
  String _nearMissText = "";
  double _nearMissTextOpacity = 0.0;
  double _nearMissTextY = 0.0;
  double _nearMissTextScale = 1.0;
  EyeExpression _eyeExpression = EyeExpression.normal;

  // ── Sürükleme ve X Pozisyonu ──
  double _joleX = 0.0;
  double _targetX = 0.0;

  // ── Seviye (Level) Sistemi ──
  int _level = 1;
  int _levelProgress = 0;
  String _levelUpText = "";
  double _levelUpOpacity = 0.0;
  double _levelUpScale = 1.0;

  // ── Jöle Boyutları ──
  static const double _defaultWidth = 55.0;
  static const double _defaultHeight = 55.0;

  static const double _flatWidth = 135.0;
  static const double _flatHeight = 25.0;

  double _joleWidth = _defaultWidth;
  double _joleHeight = _defaultHeight;
  bool _isPressed = false;

  double _targetWidth = _defaultWidth;
  double _targetHeight = _defaultHeight;

  // ── Kostüm Dükkanı (Skins) ──
  late List<JellySkin> _skins;
  int _selectedSkinIndex = 0;

  // Menü Jölesi için Bouncy efekt değişkenleri
  double _menuJellyScale = 1.0;

  // ── Kombo & Kalkan (Combo & Shield) ──
  int _comboCount = 0;
  bool _hasShield = false;
  double _shieldPulse = 1.0;
  bool _shieldPulseDirection = true;

  // ── Ateş Modu (Fever Mode) ──
  double _feverProgress = 0.0;
  bool _isFeverMode = false;
  double _feverTimeLeft = 0.0;

  // ── Efekt ve Nesne Listeleri ──
  final List<Obstacle> _obstacles = [];
  final List<GameGem> _gems = [];
  final List<JellyTrail> _trails = [];
  final List<SpeedLine> _speedLines = [];
  final List<_Particle> _particles = [];
  final List<_Star> _stars = [];
  final Random _random = Random();

  double _baseSpeed = 4.0;
  double _currentSpeed = 4.0;
  double _spawnTimer = 0;
  double _spawnInterval = 100;

  late AnimationController _gameLoopController;

  @override
  void initState() {
    super.initState();
    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_gameLoop);

    // Kostümleri tanımla
    _skins = [
      JellySkin(name: 'Yeşil Jöle', primaryColor: const Color(0xFF00FF87), glowColor: const Color(0xFF60EFA0), cost: 0, isUnlocked: true),
      JellySkin(name: 'Neon Mavi', primaryColor: const Color(0xFF00F2FE), glowColor: const Color(0xFF4FACFE), cost: 10, isUnlocked: false),
      JellySkin(name: 'Lava Turuncu', primaryColor: const Color(0xFFFF4E50), glowColor: const Color(0xFFF9D423), cost: 25, isUnlocked: false),
      JellySkin(name: 'Siber Pembe', primaryColor: const Color(0xFFF107A3), glowColor: const Color(0xFFFF75B5), cost: 45, isUnlocked: false),
      JellySkin(name: 'Kraliyet Altını', primaryColor: const Color(0xFFFFD700), glowColor: const Color(0xFFFF8C00), cost: 75, isUnlocked: false),
    ];
  }

  @override
  void dispose() {
    _gameLoopController.dispose();
    super.dispose();
  }

  // ── Arka Plan Efektleri ──
  void _initBackgroundEffects(Size screenSize) {
    if (_stars.isNotEmpty) return;
    for (int i = 0; i < 60; i++) {
      _stars.add(_Star(
        x: _random.nextDouble() * screenSize.width,
        y: _random.nextDouble() * screenSize.height,
        size: _random.nextDouble() * 2 + 0.5,
        speed: _random.nextDouble() * 1.0 + 0.2,
        opacity: _random.nextDouble() * 0.5 + 0.1,
      ));
    }
    for (int i = 0; i < 15; i++) {
      _speedLines.add(SpeedLine(
        x: _random.nextDouble() * screenSize.width,
        y: _random.nextDouble() * screenSize.height,
        length: _random.nextDouble() * 40 + 20,
        speed: _random.nextDouble() * 8 + 6,
      ));
    }
  }

  // ── Oyunu Başlat ──
  void _startGame() {
    final startX = MediaQuery.of(context).size.width / 2;
    setState(() {
      _gameState = GameState.playing;
      _score = 0;
      _collectedGemsCount = 0;
      _obstacles.clear();
      _gems.clear();
      _trails.clear();
      _particles.clear();
      _feverProgress = 0.0;
      _isFeverMode = false;
      _feverTimeLeft = 0.0;
      _baseSpeed = 4.0;
      _currentSpeed = 4.0;
      _spawnTimer = 0;
      _spawnInterval = 100;
      _targetWidth = _defaultWidth;
      _targetHeight = _defaultHeight;
      _joleWidth = _defaultWidth;
      _joleHeight = _defaultHeight;
      _isPressed = false;
      _comboCount = 0;
      _hasShield = false;
      _timeDilation = 1.0;
      _slowMotionDuration = 0.0;
      _nearMissText = "";
      _nearMissTextOpacity = 0.0;
      _eyeExpression = EyeExpression.normal;
      _joleX = startX;
      _targetX = startX;
      _level = 1;
      _levelProgress = 0;
      _levelUpText = "";
      _levelUpOpacity = 0.0;
    });
    _gameLoopController.repeat();
  }

  void _setPressed(bool pressed) {
    if (_gameState != GameState.playing) return;
    if (_isPressed != pressed) {
      setState(() {
        _isPressed = pressed;
      });
      _spawnSquishParticles();
    }
  }

  void _spawnSquishParticles() {
    final screenSize = MediaQuery.of(context).size;
    final joleBottom = screenSize.height - 100;
    final joleCenterX = _joleX;
    final color = _getJoleColor();
    for (int i = 0; i < 8; i++) {
      final isRight = _random.nextBool();
      final vx = (isRight ? 1.0 : -1.0) * (_random.nextDouble() * 4 + 2);
      final vy = (_random.nextDouble() - 0.5) * 3;
      _particles.add(_Particle(
        x: joleCenterX + (isRight ? _joleWidth / 2 : -_joleWidth / 2),
        y: joleBottom + (_random.nextDouble() - 0.5) * _joleHeight,
        vx: vx,
        vy: vy,
        size: _random.nextDouble() * 5 + 3.0,
        color: color.withValues(alpha: 0.7),
        life: 0.6,
      ));
    }
  }

  // ── Ekran Titretme ──
  void _triggerScreenShake(double intensity) {
    setState(() {
      _screenShakeIntensity = intensity;
    });
  }

  // ── Kalkan Kırılma Efekti ──
  void _shatterShield(double centerX, double centerY) {
    setState(() {
      _hasShield = false;
      _comboCount = 0;
      _triggerScreenShake(12.0);
    });

    for (int i = 0; i < 30; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = _random.nextDouble() * 7 + 3;
      _particles.add(_Particle(
        x: centerX,
        y: centerY,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        size: _random.nextDouble() * 6 + 3,
        color: const Color(0xFF00E5FF),
        life: 0.9,
      ));
    }
  }

  // ── Ateş Modu (Fever) ──
  void _activateFeverMode() {
    setState(() {
      _isFeverMode = true;
      _feverTimeLeft = 5.0;
      _feverProgress = 1.0;
      _currentSpeed = _baseSpeed * 2.2;
      _triggerScreenShake(12.0);
    });

    final screenSize = MediaQuery.of(context).size;
    for (int i = 0; i < 35; i++) {
      _particles.add(_Particle(
        x: screenSize.width / 2,
        y: screenSize.height / 2,
        vx: (_random.nextDouble() - 0.5) * 16,
        vy: (_random.nextDouble() - 0.5) * 16,
        size: _random.nextDouble() * 9 + 3,
        color: Colors.amberAccent,
        life: 1.0,
      ));
    }
  }

  void _deactivateFeverMode() {
    setState(() {
      _isFeverMode = false;
      _feverProgress = 0.0;
      _currentSpeed = _baseSpeed;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // OYUN DÖNGÜSÜ (GAME LOOP)
  // ─────────────────────────────────────────────────────────────
  void _gameLoop() {
    if (_gameState != GameState.playing) return;

    final screenSize = MediaQuery.of(context).size;
    _initBackgroundEffects(screenSize);

    setState(() {
      // ── Yavaş Çekim (Slow-Motion) Yönetimi ──
      if (_slowMotionDuration > 0) {
        _slowMotionDuration -= 0.016;
        if (_slowMotionDuration <= 0) {
          _timeDilation = 1.0;
        }
      }

      if (_nearMissTextOpacity > 0) {
        _nearMissTextOpacity -= 0.025;
        _nearMissTextY -= 1.0;
        _nearMissTextScale += 0.008;
      }

      if (_levelUpOpacity > 0) {
        _levelUpOpacity = (_levelUpOpacity - 0.02).clamp(0.0, 1.0);
        _levelUpScale += 0.025;
      }

      // ── Kalkan Nabız Efekti ──
      if (_hasShield) {
        if (_shieldPulseDirection) {
          _shieldPulse += 0.015;
          if (_shieldPulse >= 1.25) _shieldPulseDirection = false;
        } else {
          _shieldPulse -= 0.015;
          if (_shieldPulse <= 0.95) _shieldPulseDirection = true;
        }
      }

      // ── Ekran Titremesi Sönümleme ──
      if (_screenShakeIntensity > 0) {
        _screenShakeIntensity *= 0.88;
        if (_screenShakeIntensity < 0.2) _screenShakeIntensity = 0.0;
      }

      // ── Ateş Modu Kalan Süre Güncelleme ──
      if (_isFeverMode) {
        _feverTimeLeft -= 0.016 * _timeDilation;
        _feverProgress = (_feverTimeLeft / 5.0).clamp(0.0, 1.0);
        if (_feverTimeLeft <= 0) {
          _deactivateFeverMode();
        }
      }

      // ── Efektlerin Aşağı Akışı ──
      for (var star in _stars) {
        star.y += star.speed * (_isFeverMode ? 3.0 : 1.0) * _timeDilation;
        if (star.y > screenSize.height) {
          star.y = 0;
          star.x = _random.nextDouble() * screenSize.width;
        }
      }

      for (var line in _speedLines) {
        line.y += line.speed * (_isFeverMode ? 3.0 : 1.0) * _timeDilation;
        if (line.y > screenSize.height) {
          line.y = -line.length;
          line.x = _random.nextDouble() * screenSize.width;
        }
      }

      // ── Jöle Şekil Değişimi Yumuşatma ──
      if (_isPressed) {
        _targetWidth = _flatWidth;
        _targetHeight = _flatHeight;
      } else {
        _targetWidth = _defaultWidth;
        _targetHeight = _defaultHeight;
      }

      _joleWidth += (_targetWidth - _joleWidth) * 0.28;
      _joleHeight += (_targetHeight - _joleHeight) * 0.28;

      // Yatay hareket interpolasyonu
      _joleX += (_targetX - _joleX) * 0.22;
      _joleX = _joleX.clamp(_joleWidth / 2, screenSize.width - _joleWidth / 2);

      // ── Jelly Trail (İz Efekti) ──
      final joleBottom = screenSize.height - 100;
      final joleCenterX = _joleX;
      _trails.add(JellyTrail(
        x: joleCenterX - _joleWidth / 2,
        y: joleBottom - _joleHeight / 2,
        width: _joleWidth,
        height: _joleHeight,
        color: _getJoleColor(),
        opacity: 0.35,
      ));

      for (var trail in _trails) {
        trail.opacity -= 0.05;
      }
      _trails.removeWhere((t) => t.opacity <= 0);

      // ── Parçacık Hareketleri ──
      for (var p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.life -= 0.025;
      }
      _particles.removeWhere((p) => p.life <= 0);

      // ── Hız Ayarı ──
      _currentSpeed = _isFeverMode ? _baseSpeed * 2.2 : _baseSpeed;

      // ── Üretim Döngüsü ──
      _spawnTimer += 1.0 * _timeDilation;
      if (_spawnTimer >= _spawnInterval) {
        _spawnTimer = 0;
        _spawnObstacleAndGems(screenSize);
      }

      // Engellerin İlerleyişi & X Salınımı (Oscillation)
      for (var obstacle in _obstacles) {
        obstacle.y += _currentSpeed * _timeDilation;
        if (obstacle.isMoving) {
          obstacle.phase += obstacle.oscillationSpeed * _timeDilation;
          obstacle.xOffset = sin(obstacle.phase) * obstacle.oscillationRange;
        }
      }

      // Kristal Akışı ve Magnet (Mıknatıs) Çekim Logic'i
      final joleCenter = Offset(joleCenterX, joleBottom);
      for (var gem in _gems) {
        if (!gem.collected) {
          if (_isFeverMode || _hasShield) {
            final gemCenter = Offset(gem.x + gem.size / 2, gem.y + gem.size / 2);
            final distance = (joleCenter - gemCenter).distance;
            if (distance < 180.0) {
              final direction = (joleCenter - gemCenter) / distance;
              const pullSpeed = 9.0;
              gem.x += direction.dx * pullSpeed;
              gem.y += direction.dy * pullSpeed;
            } else {
              gem.y += _currentSpeed * _timeDilation;
            }
          } else {
            gem.y += _currentSpeed * _timeDilation;
          }
        } else {
          gem.y += _currentSpeed * _timeDilation;
        }
      }

      _obstacles.removeWhere((o) => o.y > screenSize.height + 100);
      _gems.removeWhere((g) => g.y > screenSize.height + 50);

      final joleRect = Rect.fromCenter(
        center: Offset(joleCenterX, joleBottom),
        width: _joleWidth,
        height: _joleHeight,
      );

      // ── Yüz İfadesini Belirleme ──
      Obstacle? closestObstacle;
      double minDistance = double.infinity;
      for (var o in _obstacles) {
        if (o.y < joleBottom) {
          double dist = joleBottom - o.y;
          if (dist < minDistance) {
            minDistance = dist;
            closestObstacle = o;
          }
        }
      }

      if (_gameState == GameState.gameOver) {
        _eyeExpression = EyeExpression.dead;
      } else if (_isFeverMode) {
        _eyeExpression = EyeExpression.fever;
      } else if (_nearMissTextOpacity > 0.4) {
        _eyeExpression = EyeExpression.star;
      } else if (closestObstacle != null && minDistance < 160.0) {
        _eyeExpression = EyeExpression.panic;
      } else if (_isPressed) {
        _eyeExpression = EyeExpression.flat;
      } else {
        _eyeExpression = EyeExpression.normal;
      }

      // ── Kristal Toplama ve Kalkan Kazanma ──
      for (var gem in _gems) {
        if (!gem.collected) {
          final gemRect = Rect.fromLTWH(gem.x, gem.y, gem.size, gem.size);
          if (joleRect.overlaps(gemRect)) {
            gem.collected = true;
            _collectedGemsCount++;
            _totalGems++; // Toplam birikime ekle
            _score += 2;
            _comboCount++;
            _triggerScreenShake(2.0);

            // Eğer kombo 5'e ulaşırsa kalkan ver
            if (_comboCount >= 5 && !_hasShield) {
              _hasShield = true;
              // Kalkan alım dalgası parçacığı
              for (int i = 0; i < 15; i++) {
                final angle = _random.nextDouble() * 2 * pi;
                _particles.add(_Particle(
                  x: joleCenterX,
                  y: joleBottom,
                  vx: cos(angle) * 5,
                  vy: sin(angle) * 5,
                  size: 4,
                  color: const Color(0xFF00E5FF),
                  life: 0.7,
                ));
              }
            }

            // Kristal toplama pırıltıları
            for (int i = 0; i < 6; i++) {
              _particles.add(_Particle(
                x: gem.x + gem.size / 2,
                y: gem.y + gem.size / 2,
                vx: (_random.nextDouble() - 0.5) * 5,
                vy: (_random.nextDouble() - 0.5) * 5,
                size: _random.nextDouble() * 4 + 2,
                color: Colors.amberAccent,
                life: 0.7,
              ));
            }

            if (!_isFeverMode) {
              _feverProgress = (_feverProgress + 0.20).clamp(0.0, 1.0);
              if (_feverProgress >= 1.0) {
                _activateFeverMode();
              }
            }
          }
        }
      }

      // ── Çarpışma ve Kalkan Koruması Kontrolü ──
      for (int i = _obstacles.length - 1; i >= 0; i--) {
        final obstacle = _obstacles[i];
        final collisionRects = _getObstacleRects(obstacle, screenSize);
        bool collided = false;

        for (var rect in collisionRects) {
          if (joleRect.overlaps(rect)) {
            collided = true;
            if (_isFeverMode) {
              // Ateş modunda engeller patlar
              _obstacles.removeAt(i);
              _score += 5;
              _triggerScreenShake(6.0);
              for (int p = 0; p < 15; p++) {
                _particles.add(_Particle(
                  x: rect.center.dx,
                  y: rect.center.dy,
                  vx: (_random.nextDouble() - 0.5) * 10,
                  vy: (_random.nextDouble() - 0.5) * 10,
                  size: _random.nextDouble() * 6 + 2,
                  color: obstacle.type == ObstacleType.lowWall
                      ? Colors.orangeAccent
                      : Colors.purpleAccent,
                  life: 0.8,
                ));
              }
              break;
            }

            // Kalkan Aktifse:
            if (_hasShield) {
              _obstacles.removeAt(i);
              _shatterShield(joleCenterX, joleBottom);
              break;
            }

            // Normal Çarpışma Kontrolü
            if (obstacle.type == ObstacleType.lowWall) {
              if (_joleHeight > _flatHeight + 10) {
                _triggerGameOver(joleCenterX, joleBottom);
                return;
              }
            } else {
              _triggerGameOver(joleCenterX, joleBottom);
              return;
            }
          }
        }

        // ── NEAR MISS (Kıl Payı Kurtarma) TESPİTİ ──
        // Çarpışma yoksa ama engel jölenin dikey düzlemindeyse
        if (!collided && !obstacle.scored && (obstacle.y - joleBottom).abs() < 50) {
          bool nearMissPossible = false;
          if (obstacle.type == ObstacleType.narrowTunnel) {
            final centerX = obstacle.gapCenterX + obstacle.xOffset;
            final halfGap = obstacle.gapWidth / 2;
            final joleLeft = joleCenterX - _joleWidth / 2;
            final joleRight = joleCenterX + _joleWidth / 2;

            // Oyuncu tünelin tam kenar sınırından kıl payı geçti mi?
            final diffLeft = (joleLeft - (centerX - halfGap)).abs();
            final diffRight = (joleRight - (centerX + halfGap)).abs();
            if (diffLeft < 14 || diffRight < 14) {
              nearMissPossible = true;
            }
          } else if (obstacle.type == ObstacleType.lowWall) {
            // Yassı formu son anda aldıysa
            if (_joleHeight <= _flatHeight + 10 && _targetHeight == _flatHeight) {
              nearMissPossible = true;
            }
          }

          if (nearMissPossible && _slowMotionDuration <= 0) {
            _triggerNearMiss(joleCenterX, joleBottom);
          }
        }

        // Engel Başarıyla Geçildiğinde
        if (!obstacle.scored && obstacle.y > joleRect.bottom) {
          obstacle.scored = true;
          _score++;
          _comboCount++;
          _levelProgress++;

          if (!_isFeverMode) {
            _feverProgress = (_feverProgress + 0.05).clamp(0.0, 1.0);
            if (_feverProgress >= 1.0) {
              _activateFeverMode();
            }
          }

          // Seviye Atlama Kontrolü
          if (_levelProgress >= 8 + _level * 2) {
            _levelProgress = 0;
            _level++;
            _levelUpText = "SEVİYE $_level";
            _levelUpOpacity = 1.0;
            _levelUpScale = 0.5;
            _triggerScreenShake(12.0);

            // Level Up Partikül Efekti
            final color = _getJoleColor();
            for (int p = 0; p < 25; p++) {
              final angle = _random.nextDouble() * 2 * pi;
              final speed = _random.nextDouble() * 7 + 3;
              _particles.add(_Particle(
                x: screenSize.width / 2,
                y: screenSize.height / 2,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                size: _random.nextDouble() * 8 + 3,
                color: color,
                life: 1.0,
              ));
            }

            _baseSpeed += 0.6;
            if (_spawnInterval > 40) {
              _spawnInterval -= 6;
            }
          }
        }
      }
    });
  }

  void _triggerNearMiss(double centerX, double centerY) {
    setState(() {
      _timeDilation = 0.25;
      _slowMotionDuration = 0.6; // Gerçek zamanda ~600ms yavaşlama
      _nearMissText = _random.nextBool() ? "KIL PAYI!" : "NICE SHIFT!";
      _nearMissTextOpacity = 1.0;
      _nearMissTextY = centerY - 110;
      _nearMissTextScale = 0.75;
      _score += 3;
      _comboCount += 1;
      _triggerScreenShake(6.0);
    });

    // Havalı halka şeklinde neon partiküller yayalım
    for (int i = 0; i < 16; i++) {
      final angle = i * (2 * pi / 16);
      _particles.add(_Particle(
        x: centerX,
        y: centerY,
        vx: cos(angle) * 7.5,
        vy: sin(angle) * 7.5,
        size: 5.0,
        color: const Color(0xFF00E5FF),
        life: 0.8,
      ));
    }
  }

  // ── Engelleri ve Kristalleri Konumlandırma ──
  void _spawnObstacleAndGems(Size screenSize) {
    final type = _random.nextBool() ? ObstacleType.narrowTunnel : ObstacleType.lowWall;
    double obstacleY = -80.0;

    final isMoving = type == ObstacleType.narrowTunnel && _random.nextDouble() < 0.45;
    final oscillationRange = 35.0 + _random.nextDouble() * 30.0;
    final oscillationSpeed = 0.02 + _random.nextDouble() * 0.02;

    // Tünel için deliğin X merkezini rastgele seç, kenarlardan 50px boşluk bırak
    final gapCenterX = type == ObstacleType.narrowTunnel
        ? 50.0 + _random.nextDouble() * (screenSize.width - 100.0)
        : screenSize.width / 2;

    _obstacles.add(Obstacle(
      type: type,
      y: obstacleY,
      gapWidth: _defaultWidth + 22.0 + _random.nextDouble() * 10,
      wallHeight: _flatHeight + 15.0 + _random.nextDouble() * 10,
      gapCenterX: gapCenterX,
      isMoving: isMoving,
      oscillationRange: oscillationRange,
      oscillationSpeed: oscillationSpeed,
      phase: _random.nextDouble() * 2 * pi,
    ));

    // Kristal konumlandır
    if (_random.nextDouble() > 0.35) {
      double gemX = (type == ObstacleType.narrowTunnel ? gapCenterX : screenSize.width / 2) - 13.0;
      if (type == ObstacleType.narrowTunnel) {
        _gems.add(GameGem(x: gemX, y: obstacleY + 10));
      } else {
        _gems.add(GameGem(x: gemX, y: obstacleY - 50));
      }
    }
  }

  // ── Çarpışma Kutuları ──
  List<Rect> _getObstacleRects(Obstacle obstacle, Size screenSize) {
    switch (obstacle.type) {
      case ObstacleType.narrowTunnel:
        final centerX = obstacle.gapCenterX + obstacle.xOffset;
        final halfGap = obstacle.gapWidth / 2;
        const height = 45.0;
        return [
          Rect.fromLTWH(0, obstacle.y, (centerX - halfGap).clamp(0.0, screenSize.width), height),
          Rect.fromLTWH((centerX + halfGap).clamp(0.0, screenSize.width), obstacle.y,
              (screenSize.width - (centerX + halfGap)).clamp(0.0, screenSize.width), height),
        ];
      case ObstacleType.lowWall:
        return [
          Rect.fromLTWH(0, obstacle.y, screenSize.width, obstacle.wallHeight),
        ];
    }
  }

  // ── Oyun Bitişi ──
  void _triggerGameOver(double centerX, double centerY) {
    _gameLoopController.stop();
    _triggerScreenShake(20.0);

    _particles.clear();
    for (int i = 0; i < 40; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = _random.nextDouble() * 8 + 3;
      _particles.add(_Particle(
        x: centerX,
        y: centerY,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        size: _random.nextDouble() * 10 + 3,
        color: _getJoleColor(),
        life: 1.0,
      ));
    }

    if (_score > _highScore) {
      _highScore = _score;
    }

    _gameState = GameState.gameOver;

    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || _gameState != GameState.gameOver) {
        timer.cancel();
        return;
      }
      setState(() {
        for (var p in _particles) {
          p.x += p.vx;
          p.y += p.vy;
          p.vy += 0.2;
          p.life -= 0.025;
        }
        _particles.removeWhere((p) => p.life <= 0);
      });
    });
  }

  // ── Jöle Görünüm ve Renk Özellikleri ──
  Color _getJoleColor() {
    if (_isFeverMode) {
      final hue = (DateTime.now().millisecondsSinceEpoch / 5) % 360;
      return HSVColor.fromAHSV(1.0, hue, 0.9, 1.0).toColor();
    }
    return _skins[_selectedSkinIndex].primaryColor;
  }

  Color _getJoleGlowColor() {
    if (_isFeverMode) return Colors.white;
    return _skins[_selectedSkinIndex].glowColor;
  }

  // ── Jöle Gözlerini Çizen Widget ──
  Widget _buildJellyEye(bool isLeft) {
    double eyeSize = _joleHeight * 0.22;
    
    switch (_eyeExpression) {
      case EyeExpression.dead:
        return Text(
          '×',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: _joleHeight * 0.38,
            height: 0.9,
          ),
        );
      case EyeExpression.fever:
        return Icon(
          Icons.bolt,
          color: Colors.amberAccent,
          size: eyeSize * 1.6,
        );
      case EyeExpression.star:
        return Icon(
          Icons.star_rounded,
          color: Colors.cyanAccent,
          size: eyeSize * 1.5,
        );
      case EyeExpression.panic:
        return Text(
          isLeft ? '>' : '<',
          style: TextStyle(
            color: Colors.white,
            fontSize: eyeSize * 1.4,
            fontWeight: FontWeight.w900,
            height: 0.95,
          ),
        );
      case EyeExpression.flat:
        return Container(
          width: eyeSize * 1.4,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      case EyeExpression.normal:
        return Container(
          width: eyeSize,
          height: eyeSize,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: eyeSize * 0.45,
              height: eyeSize * 0.45,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
    }
  }

  // ── Kostüm Satın Alma / Seçme Mantığı ──
  void _handleSkinInteraction(int index) {
    final skin = _skins[index];
    setState(() {
      if (skin.isUnlocked) {
        _selectedSkinIndex = index;
      } else {
        if (_totalGems >= skin.cost) {
          _totalGems -= skin.cost;
          skin.isUnlocked = true;
          _selectedSkinIndex = index;
          _triggerScreenShake(4.0);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final joleBottom = screenSize.height - 100;
    final joleCenterX = _joleX;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (details) {
          _targetX = details.localPosition.dx.clamp(0.0, screenSize.width);
          _setPressed(true);
        },
        onPanStart: (details) {
          _targetX = details.localPosition.dx.clamp(0.0, screenSize.width);
          _setPressed(true);
        },
        onPanUpdate: (details) {
          _targetX = details.localPosition.dx.clamp(0.0, screenSize.width);
          _setPressed(true);
        },
        onPanEnd: (_) => _setPressed(false),
        onPanCancel: () => _setPressed(false),
        child: Stack(
          children: [
            // Ekran Sallanması
            Transform.translate(
              offset: _screenShakeIntensity > 0
                  ? Offset(
                      (_random.nextDouble() - 0.5) * _screenShakeIntensity,
                      (_random.nextDouble() - 0.5) * _screenShakeIntensity,
                    )
                  : Offset.zero,
              child: Stack(
                children: [
                  // Arka Plan
                  Container(
                    width: screenSize.width,
                    height: screenSize.height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _isFeverMode
                            ? [
                                const Color(0xFF5f2c82),
                                const Color(0xFF49a09d),
                              ]
                            : [
                                const Color(0xFF0F0C1B),
                                const Color(0xFF1E1335),
                                const Color(0xFF22223b),
                              ],
                      ),
                    ),
                  ),

                  // Yıldızlar
                  ..._stars.map((star) => Positioned(
                        left: star.x,
                        top: star.y,
                        child: Container(
                          width: star.size,
                          height: star.size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: star.opacity),
                          ),
                        ),
                      )),

                  // Hız çizgileri
                  ..._speedLines.map((line) => Positioned(
                        left: line.x,
                        top: line.y,
                        child: Container(
                          width: 1.2,
                          height: line.length,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: _isFeverMode ? 0.6 : 0.2),
                              ],
                            ),
                          ),
                        ),
                      )),

                  // Engeller (Tünel)
                  ..._obstacles
                      .where((o) => o.type == ObstacleType.narrowTunnel)
                      .map((o) => _buildObstacle(o, screenSize)),

                  // Kristalleri Çiz
                  ..._gems.where((g) => !g.collected).map((gem) => Positioned(
                        left: gem.x,
                        top: gem.y,
                        child: _buildGemWidget(gem),
                      )),

                  // İzler
                  ..._trails.map((trail) => Positioned(
                        left: trail.x,
                        top: trail.y,
                        child: Opacity(
                          opacity: trail.opacity.clamp(0.0, 1.0),
                          child: Container(
                            width: trail.width,
                            height: trail.height,
                            decoration: BoxDecoration(
                              color: trail.color.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )),

                  // Jöle (Oyuncu)
                  if (_gameState == GameState.playing || _gameState == GameState.gameOver)
                    Positioned(
                      top: joleBottom - _joleHeight / 2,
                      left: joleCenterX - _joleWidth / 2,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Kalkan Küresi (Varsa)
                          if (_hasShield)
                            Positioned(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                width: max(_joleWidth, _joleHeight) * 1.5 * _shieldPulse,
                                height: max(_joleWidth, _joleHeight) * 1.5 * _shieldPulse,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                              ),
                            ),

                          // Jöle Bedeni
                          Container(
                            width: _joleWidth,
                            height: _joleHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _getJoleColor(),
                                  _getJoleColor().withValues(alpha: 0.75),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                _isPressed ? 8.0 : 16.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _getJoleGlowColor().withValues(alpha: 0.7),
                                  blurRadius: _isFeverMode ? 35 : 20,
                                  spreadRadius: _isFeverMode ? 6 : 2,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Parlama gölgesi
                                Positioned(
                                  top: 3,
                                  left: 3,
                                  right: 3,
                                  child: Container(
                                    height: _joleHeight * 0.2,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.white.withValues(alpha: 0.25),
                                    ),
                                  ),
                                ),
                                // ── DİNAMİK SEVİMLİ GÖZLER ──
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: _joleWidth * 0.12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildJellyEye(true),
                                        _buildJellyEye(false),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Engeller (Alçak Duvar)
                  ..._obstacles
                      .where((o) => o.type == ObstacleType.lowWall)
                      .map((o) => _buildObstacle(o, screenSize)),

                  // Patlamalar
                  ..._particles.where((p) => p.life > 0).map((p) => Positioned(
                        left: p.x - p.size / 2,
                        top: p.y - p.size / 2,
                        child: Opacity(
                          opacity: p.life.clamp(0.0, 1.0),
                          child: Container(
                            width: p.size,
                            height: p.size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.color,
                            ),
                          ),
                        ),
                      )),
                ],
              ),
            ),

            // ── ÜST ARAYÜZ KATMANI ──

            // Near Miss Bildirimi (Kıl Payı)
            if (_nearMissTextOpacity > 0)
              Positioned(
                top: _nearMissTextY,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: _nearMissTextOpacity.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _nearMissTextScale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.8),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.4),
                              blurRadius: 15,
                            )
                          ],
                        ),
                        child: Text(
                          _nearMissText,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.cyanAccent,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Seviye Atlama (Level Up) Bildirimi
            if (_levelUpOpacity > 0)
              Positioned(
                top: screenSize.height / 3,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: _levelUpOpacity.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _levelUpScale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.amberAccent.withValues(alpha: 0.9),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amberAccent.withValues(alpha: 0.4),
                              blurRadius: 25,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'SEVİYE ATLADI!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.amberAccent,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _levelUpText,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Oyun İçi Panel
            if (_gameState == GameState.playing)
              Positioned(
                top: 50,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Seviye Göstergesi
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.amberAccent.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'SEVİYE $_level',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amberAccent,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Ateş Modu Göstergesi
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    color: _isFeverMode ? Colors.orangeAccent : Colors.white30,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isFeverMode ? 'ATEŞ MODU!' : 'GÜÇ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _isFeverMode ? Colors.orangeAccent : Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Kalkan Bildirimi
                        if (_hasShield)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.shield, color: Color(0xFF00E5FF), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'KALKAN AKTİF',
                                  style: TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Skor ve Yıldızlar
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 3),
                            Text(
                              '$_collectedGemsCount',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Text(
                              '$_score',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Ateş Barı
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 6,
                        child: LinearProgressIndicator(
                          value: _feverProgress,
                          backgroundColor: Colors.white12,
                          color: _isFeverMode ? Colors.amber : Colors.cyanAccent,
                        ),
                      ),
                    ),

                    // Kombo Göstergesi
                    if (_comboCount >= 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'KOMBO x$_comboCount ${_hasShield ? "(🛡️)" : ""}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyanAccent.withValues(alpha: 0.8),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Menüler
            if (_gameState == GameState.menu) _buildMenuScreen(screenSize),
            if (_gameState == GameState.gameOver) _buildGameOverScreen(screenSize),
          ],
        ),
      ),
    );
  }

  // ── Kristal Tasarımı ──
  Widget _buildGemWidget(GameGem gem) {
    return Container(
      width: gem.size,
      height: gem.size,
      decoration: BoxDecoration(
        color: Colors.amberAccent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.8),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: const Icon(
        Icons.star_rounded,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  // ── Engel Widget ──
  Widget _buildObstacle(Obstacle obstacle, Size screenSize) {
    switch (obstacle.type) {
      case ObstacleType.narrowTunnel:
        return _buildNarrowTunnel(obstacle, screenSize);
      case ObstacleType.lowWall:
        return _buildLowWall(obstacle, screenSize);
    }
  }

  Widget _buildNarrowTunnel(Obstacle obstacle, Size screenSize) {
    final centerX = obstacle.gapCenterX + obstacle.xOffset;
    final halfGap = obstacle.gapWidth / 2;
    const height = 45.0;

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: obstacle.y,
          child: Container(
            width: (centerX - halfGap).clamp(0.0, screenSize.width),
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3e1c73), Color(0xFFb75d77)],
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.4),
                  blurRadius: 12,
                )
              ],
            ),
          ),
        ),
        Positioned(
          left: (centerX + halfGap).clamp(0.0, screenSize.width),
          top: obstacle.y,
          child: Container(
            width: (screenSize.width - (centerX + halfGap)).clamp(0.0, screenSize.width),
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFb75d77), Color(0xFF3e1c73)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.4),
                  blurRadius: 12,
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLowWall(Obstacle obstacle, Size screenSize) {
    return Positioned(
      left: 0,
      top: obstacle.y,
      child: Container(
        width: screenSize.width,
        height: obstacle.wallHeight,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFff9966), Color(0xFFff5e62)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.5),
              blurRadius: 16,
            )
          ],
        ),
        child: const Center(
          child: Text(
            '▼ BASILI TUT VE KAY ▼',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  // ── Başlangıç Menüsü & Kostüm Dükkanı ──
  Widget _buildMenuScreen(Size screenSize) {
    return Container(
      width: screenSize.width,
      height: screenSize.height,
      color: Colors.black87,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // İnteraktif Tıklanabilir Jöle (Giriş Ekranı Bouncy Jelly)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _menuJellyScale = 0.6;
                  });
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      setState(() {
                        _menuJellyScale = 1.0;
                      });
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.elasticOut,
                  width: 80 * _menuJellyScale,
                  height: 80 * (2.0 - _menuJellyScale),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _skins[_selectedSkinIndex].primaryColor,
                        _skins[_selectedSkinIndex].primaryColor.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _skins[_selectedSkinIndex].glowColor.withValues(alpha: 0.7),
                        blurRadius: 25,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Center(
                            child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
                          ),
                        ),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Center(
                            child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'JÖLE',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 10,
                ),
              ),
              const Text(
                'SHAPESHIFTER',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white30,
                  letterSpacing: 5,
                ),
              ),
              const SizedBox(height: 20),

              // ── KOSTÜM DÜKKANI (SHOP) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'KOSTÜM SEÇ / SATIN AL',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.5),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text('$_totalGems', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 85,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _skins.length,
                        itemBuilder: (context, index) {
                          final skin = _skins[index];
                          final isSelected = _selectedSkinIndex == index;
                          return GestureDetector(
                            onTap: () => _handleSkinInteraction(index),
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white10 : Colors.black45,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? skin.primaryColor
                                      : (skin.isUnlocked ? Colors.white24 : Colors.redAccent.withValues(alpha: 0.5)),
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 25,
                                    height: 25,
                                    decoration: BoxDecoration(
                                      color: skin.primaryColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: skin.glowColor.withValues(alpha: 0.6), blurRadius: 6)
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    skin.isUnlocked ? (isSelected ? 'SEÇİLDİ' : 'SEÇ') : '${skin.cost} ⭐',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? skin.primaryColor : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),
              // Talimat Kartı
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Oyun Kuralları & Taktikler',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.cyanAccent),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '👉 BASILI TUT -> Jöle Yassılaşır (Turuncu duvardan geç)\n'
                      '👉 BIRAK -> Jöle Kare Olur (Mor tünelden geç)\n'
                      '⭐ 5 Kombo yaparsan Kalkan (🛡️) kazanırsın!\n'
                      '⭐ Kristalleri toplayarak Ateş Modunu (🔥) aç!',
                      textAlign: TextAlign.left,
                      style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _skins[_selectedSkinIndex].primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 10,
                  shadowColor: _skins[_selectedSkinIndex].glowColor,
                ),
                child: const Text(
                  'OYUNA BAŞLA',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              if (_highScore > 0)
                Text(
                  'EN YÜKSEK SKOR: $_highScore',
                  style: const TextStyle(fontSize: 13, color: Colors.white30, letterSpacing: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Game Over Ekranı ──
  Widget _buildGameOverScreen(Size screenSize) {
    return Container(
      width: screenSize.width,
      height: screenSize.height,
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ELENDİNİZ',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Colors.redAccent,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Skor: $_score',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  'Kazanılan Yıldız: +$_collectedGemsCount',
                  style: const TextStyle(fontSize: 16, color: Colors.amber, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'En Yüksek Skor: $_highScore',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('TEKRAR OYNA', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () {
                setState(() {
                  _gameState = GameState.menu;
                  _obstacles.clear();
                  _gems.clear();
                });
              },
              child: const Text(
                'ANA MENÜYE DÖN',
                style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Star {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;

  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double life;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.life,
  });
}
