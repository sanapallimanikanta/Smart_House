import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'esp_code.dart';

bool _firebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseInitialized = true;
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }
  runApp(const LEDControlApp());
}

class LEDControlApp extends StatefulWidget {
  const LEDControlApp({Key? key}) : super(key: key);

  @override
  State<LEDControlApp> createState() => _LEDControlAppState();
}

class _LEDControlAppState extends State<LEDControlApp> {
  Color primaryColor = const Color(0xFF00E5FF);
  Color bgColor = const Color(0xFF020412);
  Color secondaryColor = const Color(0xFF1B00FF);

  void changeTheme(Color p, Color b, Color s) {
    setState(() {
      primaryColor = p;
      bgColor = b;
      secondaryColor = s;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumina Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        primaryColor: primaryColor,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          secondary: secondaryColor,
          background: bgColor,
          surface: Color.lerp(bgColor, Colors.white, 0.05)!,
        ),
        fontFamily: 'Outfit',
      ),
      home: const AuthGate(),
    );
  }
}

// --- AUTH GATE ---
class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) {
          return const LoginPage();
        }
        return SplashScreen(onThemeChange: (p, b, s) {
          final state = context.findAncestorStateOfType<_LEDControlAppState>();
          state?.changeTheme(p, b, s);
        });
      },
    );
  }
}

// --- LOGIN PAGE ---
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      if (!_firebaseInitialized) {
        throw "Firebase not initialized. Check your configuration.";
      }
      
      if (kIsWeb) {
        debugPrint("Attempting Web Sign In with Popup...");
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        // Adding scopes can sometimes help
        googleProvider.addScope('https://www.googleapis.com/auth/userinfo.email');
        await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        debugPrint("Attempting Mobile Sign In...");
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
        if (googleAuth != null) {
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await FirebaseAuth.instance.signInWithCredential(credential);
        }
      }
    } catch (e) {
      debugPrint("Login Error Details: $e");
      String errorMsg = e.toString();
      if (errorMsg.contains("UnimplementedError")) {
        errorMsg = "Platform implementation error. Please rebuild the app (flutter build web).";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Login Failed: $errorMsg"),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        )
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF020412), Color(0xFF0A0E27)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.blur_on, size: 80, color: Color(0xFF00E5FF)),
              const SizedBox(height: 20),
              const Text('LUMINA ELITE', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 8)),
              const SizedBox(height: 10),
              const Text('Smart Home Ecosystem', style: TextStyle(color: Colors.white38, letterSpacing: 2)),
              const SizedBox(height: 60),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png', width: 24, height: 24),
                  label: const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MODELS ---
class LEDData {
  String id;
  String name;
  String type; // 'bulb', 'fan', 'tv', 'washing', 'plug', etc.
  String room; // 'Living Room', 'Kitchen', 'Bedroom', etc.
  bool isOn;
  int? relayPin; 
  TimeOfDay? scheduledStartTime; 
  TimeOfDay? scheduledEndTime;   
  
  LEDData({
    required this.id, 
    required this.name, 
    this.type = 'bulb',
    this.room = 'Living Room',
    this.isOn = false,
    this.relayPin,
    this.scheduledStartTime,
    this.scheduledEndTime,
  });
}

// --- SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  final Function(Color, Color, Color) onThemeChange;
  const SplashScreen({Key? key, required this.onThemeChange}) : super(key: key);
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _drawController;
  late AnimationController _glowController;
  
  @override
  void initState() {
    super.initState();
    _drawController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);
    _glowController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);

    _drawController.forward().then((_) {
      _glowController.repeat(reverse: true);
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, anim1, anim2) => LEDControlPage(onThemeChange: widget.onThemeChange),
              transitionsBuilder: (context, anim1, anim2, child) => FadeTransition(opacity: anim1, child: child),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _drawController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_drawController, _glowController]),
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(100, 150),
                  painter: LEDLogoPainter(
                    drawProgress: _drawController.value,
                    glowIntensity: _glowController.value,
                    color: Theme.of(context).primaryColor,
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const Text('LUMINA', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 10)),
          ],
        ),
      ),
    );
  }
}

class LEDLogoPainter extends CustomPainter {
  final double drawProgress;
  final double glowIntensity;
  final Color color;
  LEDLogoPainter({required this.drawProgress, required this.glowIntensity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.3 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final centerX = size.width * 0.5;
    final baseY = size.height * 0.7;
    
    // --- Phase 1: Dot to Horizontal Line (0.0 - 0.2) ---
    double lineProgress = (drawProgress / 0.2).clamp(0.0, 1.0);
    double halfWidth = 25.0 * lineProgress;
    canvas.drawLine(Offset(centerX - halfWidth, baseY), Offset(centerX + halfWidth, baseY), paint);

    // --- Phase 2: Legs shooting down (0.2 - 0.4) ---
    if (drawProgress > 0.2) {
      double legProgress = ((drawProgress - 0.2) / 0.2).clamp(0.0, 1.0);
      double legHeight = 40.0 * legProgress;
      // Left leg
      canvas.drawLine(Offset(centerX - 10, baseY), Offset(centerX - 10, baseY + legHeight), paint);
      // Right leg
      canvas.drawLine(Offset(centerX + 10, baseY), Offset(centerX + 10, baseY + legHeight), paint);
    }

    // --- Phase 3: Dome structure growing up (0.4 - 0.9) ---
    if (drawProgress > 0.4) {
      double bodyProgress = ((drawProgress - 0.4) / 0.5).clamp(0.0, 1.0);
      Path dome = Path();
      // Start from left side of the base line
      dome.moveTo(centerX - 25, baseY);
      dome.lineTo(centerX - 25, baseY - 30); // Side wall
      dome.arcToPoint(
        Offset(centerX + 25, baseY - 30),
        radius: const Radius.circular(25),
        clockwise: true,
      );
      dome.lineTo(centerX + 25, baseY); // Right side wall back to base
      
      final metrics = dome.computeMetrics();
      for (final metric in metrics) {
        final path = metric.extractPath(0, metric.length * bodyProgress);
        canvas.drawPath(path, paint);
      }
    }

    // --- Phase 4: Glow Rays (0.9 - 1.0) ---
    if (drawProgress >= 0.9) {
      final rayPaint = Paint()
        ..color = color.withOpacity(0.8 * glowIntensity)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      double domeCenterY = baseY - 45;
      for (int i = 0; i < 5; i++) {
        double angle = -pi + (i * pi / 4);
        double startR = 30;
        double endR = 45 + (15 * glowIntensity);
        canvas.drawLine(
          Offset(centerX + cos(angle)*startR, domeCenterY + sin(angle)*startR),
          Offset(centerX + cos(angle)*endR, domeCenterY + sin(angle)*endR),
          rayPaint
        );
      }
      canvas.drawCircle(Offset(centerX, domeCenterY + 10), 20, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- MAIN PAGE ---
class LEDControlPage extends StatefulWidget {
  final Function(Color, Color, Color) onThemeChange;
  const LEDControlPage({Key? key, required this.onThemeChange}) : super(key: key);
  @override
  State<LEDControlPage> createState() => _LEDControlPageState();
}

class _LEDControlPageState extends State<LEDControlPage> {
  late DatabaseReference _database;
  double humidity = 0.0;
  int lastSeen = 0;
  bool isOnline = false;
  String activeRoom = 'All';
  List<LEDData> leds = [];
  Timer? _schedulerTimer;

  final List<String> roomList = ['All', 'Living Room', 'Kitchen', 'Bedroom', 'Office', 'Garage'];

  bool enableExternalRelays = false;
  // Pin pool split for priority
  final List<int> _onboardPins = [32, 33, 25, 26, 27, 14, 12, 23];
  final List<int> _externalPins = [22, 21, 19, 18, 5, 17];
  
  // Dynamic getter for available pins based on unlock state
  List<int> get _allPinPool => enableExternalRelays 
      ? [..._onboardPins, ..._externalPins] 
      : _onboardPins;

  // New Dynamic Variables
  double blockScale = 1.0;
  double globalGlowIntensity = 1.0;
  String wifiSSID = "";
  String wifiPassword = "";

  // AI & Voice Variables
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  String _aiResponse = "";
  bool _isAiProcessing = false;
  bool _isAddingDevice = false;

  // Stream Subscriptions for proper cleanup
  final List<StreamSubscription> _subs = [];
  Timer? _statusTimer;

  String _getHomeId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "demo";
    // Using first 6 characters of UID for a simple, short, but unique ID
    return user.uid.substring(0, 6).toLowerCase();
  }

  void _clearAllData() async {
     bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        title: const Text('FACTORY RESET', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text('This will delete all your devices and settings permanently. Are you sure?'),
        actions: [
          TextButton(child: const Text('CANCEL'), onPressed: () => Navigator.pop(context, false)),
          TextButton(
            child: const Text('RESET ALL', style: TextStyle(color: Colors.redAccent)), 
            onPressed: () => Navigator.pop(context, true)
          ),
        ],
      ),
    );

    if (confirm == true && _firebaseInitialized) {
      await _database.remove();
      setState(() {
        leds = [];
        humidity = 0.0;
        isOnline = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ecosystem reset successful.')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initVoice();
    _setupFirebase();
    _startScheduler();
  }

  void _setupFirebase() {
    if (_firebaseInitialized) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String homeId = _getHomeId();
        debugPrint("Initializing Database for Home ID: $homeId");
        _database = FirebaseDatabase.instance.ref().child('users').child(homeId);
        _listenToData();
      } else {
        debugPrint("No user found, staying in demo mode.");
        setState(() {
          leds = [LEDData(id: '1', name: 'LED 1 Demo')];
        });
      }
    } else {
      debugPrint("Firebase not initialized, staying in demo mode.");
      setState(() {
        leds = [LEDData(id: '1', name: 'LED 1 Demo')];
      });
    }
  }

  void _startScheduler() {
    _schedulerTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final now = TimeOfDay.now();
      for (int i = 0; i < leds.length; i++) {
        final led = leds[i];
        if (led.scheduledStartTime != null && led.scheduledStartTime!.hour == now.hour && led.scheduledStartTime!.minute == now.minute && !led.isOn) {
           _toggle(i, forceState: true);
        }
        if (led.scheduledEndTime != null && led.scheduledEndTime!.hour == now.hour && led.scheduledEndTime!.minute == now.minute && led.isOn) {
           _toggle(i, forceState: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _schedulerTimer?.cancel();
    _statusTimer?.cancel();
    for (var s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _listenToData() {
    _subs.add(_database.child('humidity').onValue.listen((e) {
      if (mounted && e.snapshot.value != null) setState(() => humidity = double.tryParse(e.snapshot.value.toString()) ?? 0.0);
    }, onError: (err) => debugPrint("Humidity stream error: $err")));
    
    _subs.add(_database.child('last_seen').onValue.listen((e) {
      if (mounted && e.snapshot.value != null) {
        setState(() {
          lastSeen = int.tryParse(e.snapshot.value.toString()) ?? 0;
          isOnline = true; 
        });
      }
    }, onError: (err) => debugPrint("Status stream error: $err")));

    _subs.add(_database.child('leds').onValue.listen((e) {
      final data = e.snapshot.value;
      if (mounted) {
        final List<LEDData> loaded = [];
        if (data is Map) {
          data.forEach((k, v) {
            if (v is Map) loaded.add(_parseLED(k.toString(), v));
          });
        } else if (data is List) {
          for (int i = 0; i < data.length; i++) {
            if (data[i] is Map) loaded.add(_parseLED(i.toString(), data[i]));
          }
        }
        loaded.sort((a, b) => a.id.compareTo(b.id));
        setState(() => leds = loaded);
      }
    }, onError: (err) => debugPrint("LEDs stream error: $err")));
  }

  LEDData _parseLED(String id, Map v) {
    return LEDData(
      id: id, 
      name: v['name'] ?? 'Device', 
      type: v['type'] ?? 'bulb',
      room: v['room'] ?? 'Living Room',
      isOn: v['isOn'] == true,
      relayPin: v['pin'],
      scheduledStartTime: v['start_h'] != null ? TimeOfDay(hour: v['start_h'], minute: v['start_m']) : null,
      scheduledEndTime: v['end_h'] != null ? TimeOfDay(hour: v['end_h'], minute: v['end_m']) : null,
    );
  }

  void _toggle(int i, {bool? forceState}) {
    if (i < 0 || i >= leds.length) return;
    bool newState = forceState ?? !leds[i].isOn;
    if (_firebaseInitialized) {
      _database.child('leds/${leds[i].id}/isOn').set(newState);
    } else {
      setState(() => leds[i].isOn = newState);
    }
  }

  void _deleteDevice(int i) {
    if (!_firebaseInitialized) return;
    _database.child('leds/${leds[i].id}').remove();
  }

  void _renameDevice(int i) {
    if (!_firebaseInitialized) return;
    final controller = TextEditingController(text: leds[i].name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('RENAME DEVICE', 
          style: TextStyle(
            color: Theme.of(context).primaryColor, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 1.5,
            fontSize: 16
          )
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new name',
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38))
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _database.child('leds/${leds[i].id}/name').set(controller.text.trim());
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              foregroundColor: Theme.of(context).primaryColor,
              elevation: 0,
            ),
            child: const Text('SAVE NAME'),
          ),
        ],
      ),
    );
  }

  void _addDevice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A0E27),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ADD NEW DEVICE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 25),
            Wrap(
              spacing: 20, runSpacing: 20,
              children: [
                _addTypeOption(Icons.lightbulb, 'Bulb', 'bulb'),
                _addTypeOption(Icons.cyclone, 'Fan', 'fan'),
                _addTypeOption(Icons.tv, 'TV', 'tv'),
                _addTypeOption(Icons.wash, 'Washer', 'washing'),
                _addTypeOption(Icons.power_settings_new, 'Plug', 'plug'),
                _addTypeOption(Icons.router, 'Router', 'router'),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _addTypeOption(IconData icon, String label, String type) {
    return GestureDetector(
      onTap: () async {
        if (!_firebaseInitialized) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firebase not ready. Please wait.')));
          return;
        }
        if (_isAddingDevice) return;
        setState(() => _isAddingDevice = true);
        Navigator.pop(context);

        try {
          // PIN ASSIGNMENT
          List<int> usedPins = leds.where((l) => l.relayPin != null).map((l) => l.relayPin!).toList();
          int? assignedPin;
          for (int p in _allPinPool) {
            if (!usedPins.contains(p)) { assignedPin = p; break; }
          }

          if (assignedPin == null) {
            String msg = enableExternalRelays 
                ? 'Hardware Limit Reached (14 Relays Max)!' 
                : 'Onboard Relays Full! Unlock External Ports in ESP Code menu.';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));
            setState(() => _isAddingDevice = false);
            return;
          }

          // TITANIUM SEQUENTIAL NAMING
          int nextNum = 1;
          Set<int> taken = {};
          final numScanner = RegExp(r'(\d+)');
          
          for (var l in leds) {
            if (l.type == type) {
              final matches = numScanner.allMatches(l.name);
              if (matches.isNotEmpty) {
                final val = int.tryParse(matches.last.group(0)!);
                if (val != null) taken.add(val);
              }
            }
          }
          
          while (taken.contains(nextNum)) {
            nextNum++;
          }

          // SECURE CLOUD SYNC
          final newId = DateTime.now().millisecondsSinceEpoch.toString();
          debugPrint("Adding device: $type at leds/$newId");
          
          await _database.child('leds/$newId').set({
            'name': '$label $nextNum', 
            'type': type,
            'room': activeRoom == 'All' ? 'Living Room' : activeRoom,
            'isOn': false,
            'pin': assignedPin
          });
          
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label added successfully!'), backgroundColor: Colors.green));
        } catch (e) {
          debugPrint("Error adding device: $e");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add device: $e'), backgroundColor: Colors.redAccent));
        } finally {
          if (mounted) setState(() => _isAddingDevice = false);
        }
      },
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Future<void> _showScheduler(int i) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        title: Text('Schedule ${leds[i].name}', style: TextStyle(color: Theme.of(context).primaryColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Turn ON at'),
              trailing: Text(leds[i].scheduledStartTime?.format(context) ?? '--:--'),
              onTap: () async {
                final time = await showTimePicker(context: context, initialTime: leds[i].scheduledStartTime ?? TimeOfDay.now());
                if (time != null) {
                  _database.child('leds/${leds[i].id}/start_h').set(time.hour);
                  _database.child('leds/${leds[i].id}/start_m').set(time.minute);
                  Navigator.pop(context);
                }
              },
            ),
            ListTile(
              title: const Text('Turn OFF at'),
              trailing: Text(leds[i].scheduledEndTime?.format(context) ?? '--:--'),
              onTap: () async {
                final time = await showTimePicker(context: context, initialTime: leds[i].scheduledEndTime ?? TimeOfDay.now());
                if (time != null) {
                  _database.child('leds/${leds[i].id}/end_h').set(time.hour);
                  _database.child('leds/${leds[i].id}/end_m').set(time.minute);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showESP32Code() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF020412),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: Colors.white12, width: 1)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ESP32 SOURCE CODE', 
                        style: TextStyle(
                          color: Theme.of(context).primaryColor, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 2,
                          fontSize: 16
                        )
                      ),
                      const Text('Last updated: Just now', 
                        style: TextStyle(color: Colors.white38, fontSize: 10)
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          final finalCode = esp32Code
                            .replaceFirst('#define WIFI_SSID "YOUR_WIFI_SSID"', '#define WIFI_SSID "$wifiSSID"')
                            .replaceFirst('#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"', '#define WIFI_PASSWORD "$wifiPassword"')
                            .replaceFirst('#define HOME_ID "yourname"', '#define HOME_ID "${_getHomeId()}"');
                          Clipboard.setData(ClipboardData(text: finalCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Full code copied to clipboard!'), 
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            )
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          foregroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                          side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                        ),
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        label: const Text('COPY CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white30),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            
            // NEW: EXTENSION UNLOCK BLOCK
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: enableExternalRelays ? Colors.green.withOpacity(0.05) : Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: enableExternalRelays ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    enableExternalRelays ? Icons.layers_rounded : Icons.layers_clear_outlined, 
                    color: enableExternalRelays ? Colors.greenAccent : Colors.orangeAccent
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          enableExternalRelays ? 'EXTERNAL MODES ACTIVE' : 'EXTENSION PORTS LOCKED',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                        ),
                        Text(
                          enableExternalRelays ? 'Relays 9-14 are now available for assignment.' : 'Currently limited to Onboard Relays (1-8).',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => enableExternalRelays = !enableExternalRelays),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: enableExternalRelays ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      foregroundColor: enableExternalRelays ? Colors.redAccent : Colors.greenAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      elevation: 0,
                    ),
                    child: Text(enableExternalRelays ? 'LOCK' : 'ACTIVATE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: SelectableText(
                    esp32Code
                      .replaceFirst('#define WIFI_SSID "YOUR_WIFI_SSID"', '#define WIFI_SSID "$wifiSSID"')
                      .replaceFirst('#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"', '#define WIFI_PASSWORD "$wifiPassword"')
                      .replaceFirst('#define HOME_ID "yourname"', '#define HOME_ID "${_getHomeId()}"'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFFA9B7C6),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pColor = Theme.of(context).primaryColor;
    return Scaffold(
      body: Stack(
        children: [
          Positioned(top: -100, right: -100, child: _GlowBlob(color: pColor.withOpacity(0.1), size: 300)),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: NetworkImage(FirebaseAuth.instance.currentUser?.photoURL ?? 'https://ui-avatars.com/api/?name=${FirebaseAuth.instance.currentUser?.displayName ?? 'User'}'),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(FirebaseAuth.instance.currentUser?.displayName ?? 'Smart Home User', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(FirebaseAuth.instance.currentUser?.email ?? '', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                                  ),
                                  child: SelectableText(
                                    "HOME ID: ${_getHomeId()}", 
                                    style: TextStyle(fontSize: 10, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _showESP32Code,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.code_rounded, size: 12, color: Theme.of(context).primaryColor),
                                        const SizedBox(width: 4),
                                        const Text(
                                          "ESP32 CODE", 
                                          style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          icon: const Icon(Icons.logout, size: 20, color: Colors.white30),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                   padding: const EdgeInsets.symmetric(horizontal: 20),
                   sliver: SliverList(delegate: SliverChildListDelegate([
                     const SizedBox(height: 10),
                     _buildEliteHeader(), // NEW ELITE STATUS HEADER
                     const SizedBox(height: 20),
                     _buildRoomSelector(), // NEW ROOM SELECTOR
                     const SizedBox(height: 25),
                     _buildScenarioProtocols(), // NEW QUICK ACTIONS
                     const SizedBox(height: 25),
                     _buildAIAssistantCard(),
                     const SizedBox(height: 25),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(activeRoom == 'All' ? 'System Overview' : activeRoom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                         IconButton(onPressed: _addDevice, icon: Icon(Icons.add_circle_outline, color: pColor)),
                       ],
                     ),
                     const SizedBox(height: 10),
                   ])),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, 
                      mainAxisSpacing: 12 * blockScale, 
                      crossAxisSpacing: 12 * blockScale, 
                      childAspectRatio: 0.85
                    ),
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final filteredLeds = activeRoom == 'All' 
                        ? leds 
                        : leds.where((l) => l.room == activeRoom).toList();
                      
                      return _LEDTile(
                        led: filteredLeds[i], 
                        onToggle: () => _toggle(leds.indexOf(filteredLeds[i])),
                        onSchedule: () => _showScheduler(leds.indexOf(filteredLeds[i])),
                        onDelete: () => _deleteDevice(leds.indexOf(filteredLeds[i])),
                        onRename: () => _renameDevice(leds.indexOf(filteredLeds[i])),
                        scale: blockScale,
                        glow: globalGlowIntensity,
                      );
                    }, childCount: activeRoom == 'All' ? leds.length : leds.where((l) => l.room == activeRoom).length),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEliteHeader() {
    final pColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _headerStat('TEMP', '22.4°C', Icons.thermostat, pColor),
            const VerticalDivider(color: Colors.white10, thickness: 1),
            _headerStat('HUMIDITY', '${humidity.toInt()}%', Icons.wb_cloudy_outlined, pColor),
            const VerticalDivider(color: Colors.white10, thickness: 1),
            _headerStat('POWER', '1.2 kW', Icons.bolt, pColor),
          ],
        ),
      ),
    );
  }

  Widget _headerStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 8, letterSpacing: 1, color: Colors.white38)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRoomSelector() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: roomList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          bool isSelected = activeRoom == roomList[i];
          return GestureDetector(
            onTap: () => setState(() => activeRoom = roomList[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isSelected ? Theme.of(context).primaryColor : Colors.white.withOpacity(0.05)),
              ),
              child: Text(roomList[i], style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Theme.of(context).primaryColor : Colors.white60)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScenarioProtocols() {
    return Row(
      children: [
        Expanded(child: _protocolCard('Morning Protocol', Icons.wb_sunny_outlined, Colors.orangeAccent, () {
          // Turn everything ON
          for(int i=0; i<leds.length; i++) _toggle(i, forceState: true);
        })),
        const SizedBox(width: 15),
        Expanded(child: _protocolCard('Sleep Cycle', Icons.nightlight_outlined, Colors.blueAccent, () {
           // Turn everything OFF
           for(int i=0; i<leds.length; i++) _toggle(i, forceState: false);
        })),
      ],
    );
  }

  Widget _protocolCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.05), border: Border.all(color: color.withOpacity(0.1)), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _initVoice() async {
    await Permission.microphone.request();
    bool available = await _speech.initialize(
      onStatus: (s) => debugPrint('STT Status: $s'), 
      onError: (e) => debugPrint('STT Error: $e')
    );
    if (available) {
      debugPrint("STT Initialized");
    }
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.85); // Normal human rate
  }

  void _startListening() async {
    if (!_isListening) {
      if (mounted) setState(() { _isAiProcessing = false; _aiResponse = "Waking up Lumina..."; });
      
      try {
        if (!kIsWeb) {
          var status = await Permission.microphone.request();
          if (!status.isGranted) {
             if (mounted) setState(() => _aiResponse = "Mic permission denied.");
             return;
          }
        }

        bool available = await _speech.initialize(
          onStatus: (s) {
            debugPrint('STT Status: $s');
            if (s == 'listening') setState(() => _isListening = true);
            if (s == 'notListening' || s == 'done') setState(() => _isListening = false);
          },
          onError: (val) {
            debugPrint('STT ERROR: ${val.errorMsg}');
            if (mounted) setState(() { _isListening = false; _aiResponse = "Mic Error: ${val.errorMsg}"; });
          },
          debugLogging: true,
        );

        if (available) {
          if (mounted) setState(() { _isListening = true; _aiResponse = "Lumina is listening..."; });
          _speech.listen(
            onResult: (result) {
              setState(() {
                _aiResponse = result.recognizedWords;
              });
              if (result.finalResult) {
                _processAICommand(result.recognizedWords);
              }
            },
            listenFor: const Duration(seconds: 15),
            pauseFor: const Duration(seconds: 5),
            partialResults: true,
            cancelOnError: true,
            listenMode: stt.ListenMode.confirmation,
          );
        } else {
          if (mounted) setState(() { _isListening = false; _aiResponse = "Speech not available on this browser."; });
        }
      } catch (e) {
        if (mounted) setState(() { _isListening = false; _aiResponse = "System Error: $e"; });
      }
    } else {
      _speech.stop();
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _processAICommand(String input) async {
    if (input.isEmpty) return;
    setState(() { _isAiProcessing = true; _aiResponse = "Consulting Gemini..."; });

    try {
      final String systemPrompt = """
      You are Lumina Elite (OS 2.5), a highly advanced smart home controller.
      
      DEVICES DATABASE:
      ${leds.map((l) => "- ID ${l.id}: ${l.name} in ${l.room} (Current: ${l.isOn ? 'ON' : 'OFF'})").join("\n")}
      
      ELITE CAPABILITIES:
      1. ROOM CONTROL: You can target specific rooms (Living Room, Bedroom, etc.).
      2. PROTOCOLS: You can execute "Morning Protocol" (all ON) or "Sleep Cycle" (all OFF).
      3. CRITICAL: For hardware actions, reply ONLY with a JSON object. No other text.
         Example: {"action": "control", "target": "ID", "state": true, "reply": "Turning on the lights."}
      4. Support English, Hindi, Telugu, and other languages. Detect language from user.
      """;

      // Using the most widely available stable model names
      String modelName = 'gemini-1.5-flash'; 
      
      final model = GenerativeModel(
        model: modelName, 
        apiKey: 'AIzaSyACPSQOol--JuzH_PFcTXOQo3Xs13GCeCU'
      ); 
      
      final content = [Content.text("$systemPrompt \n\n User query: $input")];
      
      // Setting a timeout to prevent infinite hang
      final response = await model.generateContent(content).timeout(const Duration(seconds: 10));
      
      String text = response.text ?? "";
      debugPrint("Gemini Response: $text");
      
      if (text.isEmpty) {
        throw "Empty response from Gemini.";
      }

      String finalReply = "I am processing that.";

      // Improved Robust JSON Extraction using Regex
      final jsonRegex = RegExp(r'\{.*\}', dotAll: true);
      final match = jsonRegex.firstMatch(text);
      
      if (match != null) {
        try {
          String jsonStr = match.group(0)!;
          final Map<String, dynamic> data = json.decode(jsonStr);
          
          if (data['action'] == 'control') {
            String targetId = data['target']?.toString() ?? "";
            bool state = data['state'] == true;
            
            bool found = false;
            for (int i = 0; i < leds.length; i++) {
              if (leds[i].id == targetId) {
                _toggle(i, forceState: state);
                found = true;
                break;
              }
            }
            if (!found) {
              debugPrint("Warning: AI targeted non-existent device ID: $targetId");
            }
          }
          finalReply = data['reply'] ?? text;
        } catch (e) {
          debugPrint("JSON Parse Error: $e");
          finalReply = text;
        }
      } else {
        // Fallback for conversational responses without actions
        finalReply = text;
      }

      if (mounted) {
        setState(() { _aiResponse = finalReply; _isAiProcessing = false; });
        try {
          await _tts.speak(finalReply);
        } catch (ttsErr) {
          debugPrint("TTS Error: $ttsErr");
        }
      }

    } catch (e) {
      debugPrint("AI Processing Error: $e");
      if (mounted) {
        setState(() { 
          _aiResponse = "Neural link offline ($e). Please try again."; 
          _isAiProcessing = false; 
        });
      }
    }
  }

  Widget _buildAIAssistantCard() {
    final pColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: _isListening ? Colors.redAccent.withOpacity(0.08) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _isListening ? Colors.redAccent.withOpacity(0.5) : pColor.withOpacity(0.12),
          width: _isListening ? 2 : 1,
        ),
        boxShadow: _isListening ? [
          BoxShadow(color: Colors.redAccent.withOpacity(0.15), blurRadius: 30, spreadRadius: 2),
          BoxShadow(color: Colors.redAccent.withOpacity(0.1), blurRadius: 10, spreadRadius: -5),
        ] : [],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildAIOrb(),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _isListening ? 'LISTENING...' : 'LUMINA AI', 
                          style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: 2, 
                            color: _isListening ? Colors.redAccent : Colors.white
                          )
                        ),
                        if (_isListening) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                            child: const Text('LIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                    const Text('Voice Multilingual Assistant', style: TextStyle(fontSize: 10, color: Colors.white38)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _startListening,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isListening)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1.0, end: 2.0),
                        duration: const Duration(seconds: 1),
                        builder: (context, value, child) {
                          return Container(
                            width: 48 * value,
                            height: 48 * value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.redAccent.withOpacity(2.0 - value), width: 2),
                            ),
                          );
                        },
                        onEnd: () {}, // Handled by repeating if state is still listening
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.redAccent : pColor.withOpacity(0.1), 
                        shape: BoxShape.circle,
                        boxShadow: _isListening ? [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 15)] : [],
                      ),
                      child: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_none_rounded, 
                        color: _isListening ? Colors.white : pColor, 
                        size: 28
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (Uri.base.scheme != 'https' && Uri.base.host != 'localhost') 
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('⚠️ Voice requires HTTPS to work. Please use a secure connection.', style: TextStyle(fontSize: 8, color: Colors.orangeAccent.withOpacity(0.5))),
            ),
          if (_aiResponse.isNotEmpty || _isAiProcessing) ...[
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20)),
              child: Text(_aiResponse, style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.white70)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAIOrb() {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [Theme.of(context).primaryColor, Colors.purpleAccent, Colors.blueAccent, Theme.of(context).primaryColor],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: const Center(child: Icon(Icons.auto_awesome, size: 18, color: Colors.white)),
    );
  }

  Widget _buildAppBar() {
    final pColor = Theme.of(context).primaryColor;
    final sColor = Theme.of(context).colorScheme.secondary;
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      title: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [pColor, sColor],
            ).createShader(bounds),
            child: const Text('Lumina', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.white)),
          ),
          const SizedBox(width: 15),
          StatusHeartIndicator(isOnline: isOnline),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _showSettings),
      ],
    );
  }

  Widget _themeOption(Color p, Color b, Color s, String name) {
    bool isSelected = Theme.of(context).primaryColor == p;
    return GestureDetector(
      onTap: () { widget.onThemeChange(p, b, s); Navigator.pop(context); },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? p.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? p : Colors.transparent),
        ),
        child: Column(
          children: [
            Container(
              width: 45, height: 45, 
              decoration: BoxDecoration(
                color: p, 
                shape: BoxShape.circle, 
                boxShadow: [BoxShadow(color: p.withOpacity(0.5), blurRadius: 10)]
              )
            ),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Center(child: Text('AURA SETTINGS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2))),
              const SizedBox(height: 30),
              
              const Text('BLOCK DYNAMICS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 1.5)),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    _controlRow('Block Size', blockScale, 0.4, 1.8, (v) {
                      setModalState(() => blockScale = v);
                      setState(() => blockScale = v);
                    }),
                    const SizedBox(height: 10),
                    _controlRow('Glow Force', globalGlowIntensity, 0.0, 2.5, (v) {
                      setModalState(() => globalGlowIntensity = v);
                      setState(() => globalGlowIntensity = v);
                    }),
                  ],
                ),
              ),
              
              const SizedBox(height: 35),
              const Text('WIFI CONFIGURATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 1.5)),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => wifiSSID = v),
                      decoration: InputDecoration(
                        labelText: 'WiFi Name (SSID)',
                        labelStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                        border: InputBorder.none,
                        hintText: wifiSSID.isEmpty ? 'Enter WiFi Name' : wifiSSID,
                        hintStyle: const TextStyle(color: Colors.white10),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const Divider(color: Colors.white10),
                    TextField(
                      onChanged: (v) => setState(() => wifiPassword = v),
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'WiFi Password',
                        labelStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                        border: InputBorder.none,
                        hintText: wifiPassword.isEmpty ? '********' : 'Stored Safely',
                        hintStyle: const TextStyle(color: Colors.white10),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 35),
              const Text('THEME PRESETS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 1.5)),
              const SizedBox(height: 15),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  children: [
                    _themeOption(const Color(0xFF00E5FF), const Color(0xFF020412), const Color(0xFF1B00FF), 'Cyber Blue'),
                    _themeOption(const Color(0xFFFF00E5), const Color(0xFF120212), const Color(0xFF6200EE), 'Neon Pink'),
                    _themeOption(const Color(0xFFE5FF00), const Color(0xFF121202), const Color(0xFF00EE62), 'Acid Green'),
                    _themeOption(const Color(0xFFFF3D00), const Color(0xFF120202), const Color(0xFFFF6D00), 'Lava Red'),
                    _themeOption(const Color(0xFF6200EE), const Color(0xFF050012), const Color(0xFFBB86FC), 'Electric Violet'),
                    _themeOption(const Color(0xFFFFAB00), const Color(0xFF120D02), const Color(0xFFFFD600), 'Solar Flare'),
                    _themeOption(const Color(0xFF81D4FA), const Color(0xFF020912), const Color(0xFFE1F5FE), 'Arctic Ice'),
                    _themeOption(const Color(0xFF00C853), const Color(0xFF021205), const Color(0xFF64DD17), 'Deep Forest'),
                    _themeOption(const Color(0xFFD500F9), const Color(0xFF080012), const Color(0xFFAA00FF), 'Magic Orchid'),
                    _themeOption(const Color(0xFFFFC107), const Color(0xFF121002), const Color(0xFFFFECB3), 'Royal Amber'),
                    _themeOption(const Color(0xFF00796B), const Color(0xFF021210), const Color(0xFFB2DFDB), 'Deep Teal'),
                    _themeOption(const Color(0xFFCFD8DC), const Color(0xFF0A0C0D), const Color(0xFFECEFF1), 'Stealth Mode'),
                  ],
                ),
              ),
              const SizedBox(height: 35),
              const Text('DANGER ZONE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent, letterSpacing: 1.5)),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _clearAllData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('RESET ECOSYSTEM', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHumidityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(Icons.wb_cloudy_outlined, color: Theme.of(context).primaryColor, size: 30),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('HUMIDITY', style: TextStyle(fontSize: 10, letterSpacing: 2)),
              Text('${humidity.toInt()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controlRow(String label, double val, double min, double max, Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white60))),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Theme.of(context).primaryColor,
            ),
            child: Slider(value: val, min: min, max: max, onChanged: onChanged),
          ),
        ),
      ],
    );
  }
}

class _LEDTile extends StatefulWidget {
  final LEDData led;
  final VoidCallback onToggle;
  final VoidCallback onSchedule;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final double scale;
  final double glow;
  const _LEDTile({
    required this.led, 
    required this.onToggle, 
    required this.onSchedule, 
    required this.onDelete,
    required this.onRename,
    required this.scale,
    required this.glow,
  });
  @override
  State<_LEDTile> createState() => _LEDTileState();
}

class _LEDTileState extends State<_LEDTile> {
  Offset _mousePos = const Offset(-1000, -1000);
  bool _isHovered = false;

  IconData _getIconForType(String type) {
    switch (type) {
      case 'fan': return Icons.cyclone;
      case 'tv': return Icons.tv;
      case 'washing': return Icons.wash;
      case 'plug': return Icons.power_settings_new;
      case 'router': return Icons.router;
      default: return Icons.lightbulb;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pColor = Theme.of(context).primaryColor;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      onHover: (e) => setState(() => _mousePos = e.localPosition),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20 * widget.scale),
          // Reduced color intensity for ON state as requested
          color: widget.led.isOn 
              ? pColor.withOpacity(0.25 * widget.glow) 
              : Colors.white.withOpacity(0.03),
          boxShadow: widget.led.isOn 
              ? [BoxShadow(color: pColor.withOpacity(0.3 * widget.glow), blurRadius: 20 * widget.glow, spreadRadius: 2)]
              : [],
          border: Border.all(
            color: widget.led.isOn ? pColor.withOpacity(0.5 * widget.glow) : Colors.white.withOpacity(0.05),
            width: 1.0,
          ),
        ),
        child: Stack(
          children: [
            CustomPaint(
              painter: _SpotlightPainter(
                mousePos: _mousePos, 
                isHovered: _isHovered, 
                color: pColor,
                intensity: widget.glow,
              ),
              size: Size.infinite,
            ),
            Column(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onToggle,
                    child: Center(
                      child: Icon(
                        _getIconForType(widget.led.type), 
                        // High-contrast SOLID constant visibility
                        color: Colors.white, 
                        size: 40 * widget.scale, 
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 10 * widget.scale),
                          Shadow(color: Colors.black, blurRadius: 20 * widget.scale),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0 * widget.scale),
                  child: Column(
                    children: [
                      Text(
                        widget.led.name, 
                        style: TextStyle(
                          fontSize: 15 * widget.scale, 
                          fontWeight: FontWeight.w900, 
                          color: Colors.white,
                          letterSpacing: -0.5,
                          // Strong shadows to stop text from hiding
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 8 * widget.scale),
                            Shadow(color: Colors.black45, blurRadius: 15 * widget.scale),
                          ]
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8 * widget.scale),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _actionBtn(Icons.edit_note_rounded, pColor.withOpacity(0.1), pColor.withOpacity(0.9), widget.onRename, widget.scale),
                          _actionBtn(Icons.schedule, pColor.withOpacity(0.1), pColor.withOpacity(0.9), widget.onSchedule, widget.scale),
                          _actionBtn(Icons.delete_outline, Colors.red.withOpacity(0.1), Colors.redAccent, widget.onDelete, widget.scale),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color bg, Color color, VoidCallback onTap, double scale) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(5 * scale),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8 * scale)),
        child: Icon(icon, size: 16 * scale, color: color),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Offset mousePos;
  final bool isHovered;
  final Color color;
  final double intensity;
  _SpotlightPainter({required this.mousePos, required this.isHovered, required this.color, required this.intensity});
  @override
  void paint(Canvas canvas, Size size) {
    if (!isHovered) return;
    
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    final ghostPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment((mousePos.dx/size.width)*2-1, (mousePos.dy/size.height)*2-1), 
        radius: 1.2, 
        colors: [color.withOpacity(0.4 * intensity), Colors.transparent]
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0 * intensity
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * intensity);
    
    final corePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment((mousePos.dx/size.width)*2-1, (mousePos.dy/size.height)*2-1), 
        radius: 0.8, 
        colors: [color.withOpacity(intensity), color.withOpacity(0.0)]
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * intensity;
    
    canvas.drawRRect(rrect, ghostPaint);
    canvas.drawRRect(rrect, corePaint);
  }
  @override
  bool shouldRepaint(_SpotlightPainter old) => true;
}

class StatusHeartIndicator extends StatefulWidget {
  final bool isOnline;
  const StatusHeartIndicator({Key? key, required this.isOnline}) : super(key: key);
  @override
  State<StatusHeartIndicator> createState() => _StatusHeartIndicatorState();
}

class _StatusHeartIndicatorState extends State<StatusHeartIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 40,
      child: CustomPaint(
        painter: HeartbeatPainter(
          progress: _controller.value,
          isOnline: widget.isOnline,
          color: widget.isOnline ? Theme.of(context).primaryColor : Colors.white24,
        ),
      ),
    );
  }
}

class HeartbeatPainter extends CustomPainter {
  final double progress;
  final bool isOnline;
  final Color color;
  HeartbeatPainter({required this.progress, required this.isOnline, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // --- Draw Heart Outline ---
    Path heartPath = Path();
    double width = size.width;
    double height = size.height;
    heartPath.moveTo(width / 2, height * 0.75);
    heartPath.cubicTo(0, height * 0.45, width * 0.1, 0, width / 2, height * 0.3);
    heartPath.cubicTo(width * 0.9, 0, width, height * 0.45, width / 2, height * 0.75);
    canvas.drawPath(heartPath, paint);
    canvas.drawPath(heartPath, glowPaint);

    // --- Draw Heartbeat Line (ECG) ---
    Path ecgPath = Path();
    double yCenter = height * 0.4;
    double startX = width * 0.2;
    double endX = width * 0.8;
    double currentX = startX + (endX - startX) * progress;

    ecgPath.moveTo(startX, yCenter);
    
    if (isOnline) {
      // Create Heartbeat Spikes
      for (double x = startX; x < endX; x += 1) {
        double localProgress = (x - startX) / (endX - startX);
        double time = (localProgress + progress) % 1.0;
        double y = yCenter;
        
        // Spike Logic (Classic PQRST wave)
        if (time > 0.1 && time < 0.15) y -= 5;      // P wave
        else if (time >= 0.15 && time < 0.2) y += 0;
        else if (time >= 0.2 && time < 0.23) y += 3; // Q
        else if (time >= 0.23 && time < 0.28) y -= 15; // R (Main Spike)
        else if (time >= 0.28 && time < 0.32) y += 5;  // S
        else if (time >= 0.4 && time < 0.5) y -= 7;    // T wave
        
        if (x == startX) ecgPath.moveTo(x, y);
        else ecgPath.lineTo(x, y);
      }
    } else {
      // Flat line (Offline)
      ecgPath.lineTo(endX, yCenter);
    }

    canvas.drawPath(ecgPath, paint..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(HeartbeatPainter old) => true;
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: size/2, spreadRadius: size/4)]));
  }
}
