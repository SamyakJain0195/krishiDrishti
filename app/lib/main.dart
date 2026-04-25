// lib/main.dart
// ignore_for_file: avoid_print, unnecessary_brace_in_string_interps, camel_case_types, deprecated_member_use, unused_element
// BirsaKisanDrishti – (real backend calls)

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'secrets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ========================================================
//                       MAIN + LANGUAGE
// ========================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Detect device language once
  final platformLocales = WidgetsBinding.instance.platformDispatcher.locales;
  if (platformLocales.isNotEmpty) {
    final code = platformLocales.first.languageCode.toLowerCase();
    if (code == 'hi') {
      appLang.value = AppLang.hi;
    } else {
      appLang.value = AppLang.en;
    }
  }

  runApp(const BirsaKisanApp());
}

enum AppLang { en, hi }

final ValueNotifier<AppLang> appLang = ValueNotifier(AppLang.en);

bool get isEn => appLang.value == AppLang.en;
bool get isHi => appLang.value == AppLang.hi;

/// simple helper – choose text by current language
String t(String en, String hi) {
  if (isEn) return en;
  return hi;
}

//  HomeScreen to show image cards
Widget _homeCard(String imgPath, String label) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(imgPath, height: 70),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    ),
  );
}

// Lightweight wrapper to unify older 'LoginScreen' with newer route name
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}

class BirsaKisanApp extends StatelessWidget {
  const BirsaKisanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: appLang,
      builder: (context, lang, _) {
        return MaterialApp(
          title: 'BirsaKisanDrishti',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: const Color(0xFF2E7D32),
            scaffoldBackgroundColor: const Color(0xFFAED581),
            useMaterial3: false,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

// small language toggle in header
class LangToggleButton extends StatelessWidget {
  const LangToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: appLang,
      builder: (context, lang, _) {
        final label = isEn ? 'हिंदी' : 'EN';
        return TextButton(
          onPressed: () {
            appLang.value = isEn ? AppLang.hi : AppLang.en;
          },
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

// ========================================================
//                       SPLASH SCREEN
// ========================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'BIRSA\nKISAN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'BirsaKisanDrishti',
              style: TextStyle(
                fontSize: 20,
                color: Colors.green.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
// ========================================================
//                       LOGIN SCREEN
// ========================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final mobileCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  bool rememberMe = false;

  bool sendingOtp = false;
  bool verifying = false;
  int otpSeconds = 0;
  Timer? otpTimer;

  final List<TextInputFormatter> mobileFormatter = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  @override
  void dispose() {
    mobileCtrl.dispose();
    otpCtrl.dispose();
    otpTimer?.cancel();
    super.dispose();
  }

  void _snack(String en, String hi) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t(en, hi))));
  }

  void _startOtpTimer() {
    otpTimer?.cancel();
    setState(() => otpSeconds = 30);
    otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (otpSeconds > 0) {
          otpSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendOtpDummy() async {
    if (mobileCtrl.text.length != 10) {
      _snack(
        'Enter 10-digit mobile number',
        '10 अंकों का मोबाइल नंबर दर्ज करें',
      );
      return;
    }
    if (otpSeconds > 0) return;

    setState(() => sendingOtp = true);
    await Future.delayed(const Duration(seconds: 1)); // fake
    if (!mounted) return;
    setState(() => sendingOtp = false);
    _startOtpTimer();
    _snack(
      'OTP sent (dummy, frontend only)',
      'ओटीपी भेजा गया (केवल फ्रंटएंड डेमो)',
    );
  }

  Future<void> _loginDummy() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => verifying = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => verifying = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  String _otpButtonText() {
    if (sendingOtp) return t('Sending...', 'भेजा जा रहा है...');
    if (otpSeconds > 0) {
      return t('Resend in $otpSeconds s', '$otpSeconds सेकंड में फिर भेजें');
    }
    return t('Get OTP', 'ओटीपी प्राप्त करें');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: Center(
        child: Container(
          width: size.width < 400 ? size.width * 0.95 : 400,
          height: size.height * 0.9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Column(
              children: [
                // header
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFA000), Color(0xFFFFC107)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 24),
                      Container(
                        height: 70,
                        width: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Image.asset(
                            'assets/images/logo.png.jpg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const LangToggleButton(),
                    ],
                  ),
                ),

                // form
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            t('Log In', 'लॉगिन'),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: mobileCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: mobileFormatter,
                            validator: (v) => v == null || v.length != 10
                                ? t(
                                    'Enter 10-digit mobile number',
                                    '10 अंकों का मोबाइल नंबर दर्ज करें',
                                  )
                                : null,
                            decoration: InputDecoration(
                              labelText: t('Mobile Number', 'मोबाइल नंबर'),
                              prefixIcon: const Icon(Icons.phone),
                              suffixIcon: TextButton(
                                onPressed: (sendingOtp || otpSeconds > 0)
                                    ? null
                                    : _sendOtpDummy,
                                child: Text(_otpButtonText()),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: otpCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            validator: (v) => v == null || v.length < 4
                                ? t('Enter valid OTP', 'सही ओटीपी दर्ज करें')
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'OTP',
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: Icon(Icons.visibility_off),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: rememberMe,
                                onChanged: (v) =>
                                    setState(() => rememberMe = v ?? false),
                              ),
                              Text(t('Remember me', 'मुझे याद रखें')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: verifying ? null : _loginDummy,
                              child: verifying
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      t('LOGIN', 'लॉगिन'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t('Don’t have an account? ', 'खाता नहीं है? '),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SignupScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  t('Sign Up', 'साइन अप'),
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// ========================================================
//                       SIGNUP SCREEN
// ========================================================

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final mobileCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  bool rememberMe = false;

  bool sendingOtp = false;
  bool verifying = false;
  int otpSeconds = 0;
  Timer? otpTimer;

  final List<TextInputFormatter> mobileFormatter = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  @override
  void dispose() {
    nameCtrl.dispose();
    mobileCtrl.dispose();
    otpCtrl.dispose();
    otpTimer?.cancel();
    super.dispose();
  }

  void _snack(String en, String hi) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t(en, hi))));
  }

  void _startOtpTimer() {
    otpTimer?.cancel();
    setState(() => otpSeconds = 30);
    otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (otpSeconds > 0) {
          otpSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendOtpDummy() async {
    if (mobileCtrl.text.length != 10) {
      _snack(
        'Enter 10-digit mobile number',
        '10 अंकों का मोबाइल नंबर दर्ज करें',
      );
      return;
    }
    if (otpSeconds > 0) return;

    setState(() => sendingOtp = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => sendingOtp = false);
    _startOtpTimer();
    _snack(
      'OTP sent (dummy, frontend only)',
      'ओटीपी भेजा गया (केवल फ्रंटएंड डेमो)',
    );
  }

  Future<void> _signupDummy() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => verifying = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => verifying = false);

    _snack(
      'Signup success (frontend only)',
      'साइन अप सफल (केवल फ्रंटएंड डेमो)',
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  String _otpButtonText() {
    if (sendingOtp) return t('Sending...', 'भेजा जा रहा है...');
    if (otpSeconds > 0) {
      return t('Resend in ${otpSeconds}s', '${otpSeconds} सेकंड में फिर भेजें');
    }
    return t('Get OTP', 'ओटीपी प्राप्त करें');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: Center(
        child: Container(
          width: size.width < 400 ? size.width * 0.95 : 400,
          height: size.height * 0.9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Column(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFA000), Color(0xFFFFC107)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 24),
                      Container(
                        height: 70,
                        width: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Image.asset(
                            'assets/images/logo.png.jpg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const LangToggleButton(),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            t('Create an account', 'खाता बनाएँ'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: nameCtrl,
                            validator: (v) => v == null || v.isEmpty
                                ? t('Enter name', 'नाम दर्ज करें')
                                : null,
                            decoration: InputDecoration(
                              labelText: t('Name', 'नाम'),
                              prefixIcon: const Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: mobileCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: mobileFormatter,
                            validator: (v) => v == null || v.length != 10
                                ? t(
                                    'Enter 10-digit mobile number',
                                    '10 अंकों का मोबाइल नंबर दर्ज करें',
                                  )
                                : null,
                            decoration: InputDecoration(
                              labelText: t('Mobile Number', 'मोबाइल नंबर'),
                              prefixIcon: const Icon(Icons.phone),
                              suffixIcon: TextButton(
                                onPressed: (sendingOtp || otpSeconds > 0)
                                    ? null
                                    : _sendOtpDummy,
                                child: Text(_otpButtonText()),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: otpCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            validator: (v) => v == null || v.length < 4
                                ? t('Enter valid OTP', 'सही ओटीपी दर्ज करें')
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'OTP',
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: Icon(Icons.visibility_off),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: rememberMe,
                                onChanged: (v) =>
                                    setState(() => rememberMe = v ?? false),
                              ),
                              Text(t('Remember me', 'मुझे याद रखें')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: verifying ? null : _signupDummy,
                              child: verifying
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      t('SIGN UP', 'साइन अप'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t(
                                  'Already have an account? ',
                                  'पहले से खाता है? ',
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  t('Login', 'लॉगिन'),
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================================
//                        MAIN SHELL
// ========================================================

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const ChatBotScreen(),
      const CommunityScreen(),
      const MyFarmPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        selectedItemColor: Colors.green.shade900,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => index = i),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            label: t('Home', 'होम'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.smart_toy_outlined),
            label: t('ChatBot', 'चैटबॉट'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.groups),
            label: t('Union', 'यूनियन'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.agriculture),
            label: t('My Farm', 'मेरा खेत'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: t('Profile', 'प्रोफ़ाइल'),
          ),
        ],
      ),
    );
  }
}

// ========================================================
//                        HOME SCREEN
// ========================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD6EDE0), Color(0xFFEFF7F3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BirsaKisanDrishti',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const LangToggleButton(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ----------------  TOP BANNER WITH BACKGROUND IMAGE  ----------------
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        image: const DecorationImage(
                          image: AssetImage("assets/images/banner_bg.png.jpg"),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t("Hello, Good Morning", "नमस्ते, शुभ सुबह"),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Sunday, 01 Jan 2025",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const TextField(
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: "Search Here...",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.only(top: 5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Manage Your Farm', 'अपने खेत को प्रबंधित करें'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t("Manage Your Farm", "अपने खेत का प्रबंधन करें"),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.15,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyFarmPage(),
                            ),
                          ),
                          child: _homeCard(
                            "assets/images/my_farm.png.jpg",
                            t("MY FARM", "मेरा खेत"),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SoilDetailsPage(),
                            ),
                          ),
                          child: _homeCard(
                            "assets/images/crop.png.jpg",
                            t("CROP", "फसल"),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MarketPriceScreen(),
                            ),
                          ),
                          child: _homeCard(
                            "assets/images/market.png.jpg",
                            t("MARKET PRICE", "बाजार मूल्य"),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DiseaseDetectionScreen(),
                            ),
                          ),
                          child: _homeCard(
                            "assets/images/disease.png.jpg",
                            t("DISEASE DETECTOR", "रोग पहचान"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridItem(
    BuildContext context,
    IconData icon,
    String label,
    Widget page,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: Colors.green.shade800),
            const SizedBox(height: 10),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ========================================================
//                    COMMON GREEN TOP BAR
// ========================================================

class GreenTopBar extends StatelessWidget {
  final String titleEn;
  final String titleHi;

  const GreenTopBar({super.key, required this.titleEn, required this.titleHi});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF2E7D32),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            t(titleEn, titleHi),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const LangToggleButton(),
        ],
      ),
    );
  }
}

// ========================================================
//                   SOIL DETAILS / CROPS
// ========================================================

class SoilDetailsPage extends StatefulWidget {
  const SoilDetailsPage({super.key});

  @override
  State<SoilDetailsPage> createState() => _SoilDetailsPageState();
}

class _SoilDetailsPageState extends State<SoilDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final nCtrl = TextEditingController();
  final pCtrl = TextEditingController();
  final kCtrl = TextEditingController();
  final phCtrl = TextEditingController();
  final soilTypeCtrl = TextEditingController();
  final irrigationCtrl = TextEditingController();
  final farmSizeCtrl = TextEditingController();
  final ocCtrl = TextEditingController(); // NEW – Organic Carbon
  final ecCtrl = TextEditingController(); // NEW – Electrical Conductivity

  final List<TextInputFormatter> intInput = [
    FilteringTextInputFormatter.digitsOnly,
  ];
  final List<TextInputFormatter> doubleInput = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
  ];

  @override
  void dispose() {
    nCtrl.dispose();
    pCtrl.dispose();
    kCtrl.dispose();
    phCtrl.dispose();
    soilTypeCtrl.dispose();
    irrigationCtrl.dispose();
    farmSizeCtrl.dispose();
    ocCtrl.dispose(); // NEW
    ecCtrl.dispose(); // NEW
    super.dispose();
  }

  Future<void> _showRecommendation() async {
    if (!_formKey.currentState!.validate()) return;

    final url = Uri.parse("http://192.168.137.129/crops/predict");

    final body = {
      "N": int.parse(nCtrl.text),
      "P": int.parse(pCtrl.text),
      "K": int.parse(kCtrl.text),
      "pH": double.parse(phCtrl.text),
      "soil_type": soilTypeCtrl.text,
      "irrigation": irrigationCtrl.text,
      "farm_size": double.parse(farmSizeCtrl.text),
      "organic_carbon": double.parse(ocCtrl.text), // NEW
      "ec": double.parse(ecCtrl.text), // NEW
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      Navigator.pop(context); // hide loader

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prediction = data["predictions"][0];

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CropRecommendationPage(predictionData: prediction),
          ), // MAP from API
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Server error")));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Network error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GreenTopBar(titleEn: 'Crops', titleHi: 'फसलें'),
              const SizedBox(height: 12),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('Soil Details', 'मिट्टी विवरण'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _soilRow(
                        'N',
                        t('Enter nitrogen value', 'नाइट्रोजन मान दर्ज करें'),
                        nCtrl,
                        intInput,
                      ),
                      const SizedBox(height: 12),
                      _soilRow(
                        'pH',
                        t('Enter pH value', 'pH मान दर्ज करें'),
                        phCtrl,
                        doubleInput,
                      ),
                      const SizedBox(height: 12),
                      _soilRow(
                        'P',
                        t('Enter phosphorus value', 'फॉस्फोरस मान दर्ज करें'),
                        pCtrl,
                        intInput,
                      ),
                      const SizedBox(height: 12),
                      _soilRow(
                        'K',
                        t('Enter potassium value', 'पोटैशियम मान दर्ज करें'),
                        kCtrl,
                        intInput,
                      ),
                      const SizedBox(height: 12),
                      _soilRow(
                        '🧪',
                        t('Enter soil type', 'मृदा का प्रकार दर्ज करें'),
                        soilTypeCtrl,
                        [], // empty = string mode
                      ),
                      const SizedBox(height: 12),
                      _soilRow(
                        '💧',
                        t('Enter irrigation method', 'सिंचाई विधि दर्ज करें'),
                        irrigationCtrl,
                        [], // empty = string mode
                      ),
                      const SizedBox(height: 12),
                      _soilRow(
                        '📏',
                        t(
                          'Enter farm size (acre/ha)',
                          'खेत का आकार दर्ज करें (एकड़/हे.)',
                        ),
                        farmSizeCtrl,
                        doubleInput,
                      ),
                      const SizedBox(height: 18),
                      _soilRow(
                        'OC',
                        t(
                          'Enter organic carbon value',
                          'जैविक कार्बन मान दर्ज करें',
                        ),
                        ocCtrl,
                        doubleInput, // float
                      ),
                      const SizedBox(height: 12),

                      _soilRow(
                        'EC',
                        t(
                          'Enter electrical conductivity value',
                          'विद्युत चालकता मान दर्ज करें',
                        ),
                        ecCtrl,
                        doubleInput, // float
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: _showRecommendation,

                          child: Text(
                            t('Get Recommendation', 'सुझाव प्राप्त करें'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _soilRow(
    String chip,
    String hint,
    TextEditingController controller,
    List<TextInputFormatter> fmts,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE0E0E0),
            child: Text(
              chip,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              inputFormatters: fmts,
              keyboardType: fmts.isEmpty
                  ? TextInputType.text
                  : TextInputType.number,
              textCapitalization: TextCapitalization.words,

              validator: (v) =>
                  v == null || v.isEmpty ? t('Required', 'आवश्यक') : null,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================================
//               CROP RECOMMENDATION DETAIL PAGE
// ========================================================

class CropRecommendationPage extends StatelessWidget {
  final Map<String, dynamic> predictionData;

  const CropRecommendationPage({super.key, required this.predictionData});

  @override
  Widget build(BuildContext context) {
    final cropName = predictionData['crop_name'] ?? 'Crop';
    final suitabilityScore =
        (predictionData['confidence_percent'] as num?)?.round() ?? 0;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFAED581),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 70,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      t('My Farm', 'मेरा खेत'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const LangToggleButton(),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                color: const Color(0xFF81C784),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cropName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('Primary Recommendation', 'प्राथमिक सुझाव'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$suitabilityScore% ${t('Suitability', 'अनुकूलता')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                child: TabBar(
                  indicatorColor: Colors.green.shade800,
                  labelColor: Colors.green.shade800,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: t('PDF', 'PDF')),
                    Tab(text: t('Details', 'विवरण')),
                    Tab(text: t('Rotation', 'रोटेशन')),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFFF4F6F9),
                  child: TabBarView(
                    children: [
                      _pdfTab(context),
                      _detailsTab(context),
                      _rotationTab(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pdfTab(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  t(
                    'PDF guide will be added later (backend).',
                    'पीडीएफ गाइड बाद में (बैकएंड) जोड़ी जाएगी।',
                  ),
                ),
              ),
            );
          },
          icon: const Icon(Icons.picture_as_pdf),
          label: Text(
            t(
              'Download Detailed Fertilizer Plan',
              'विस्तृत उर्वरक योजना डाउनलोड करें',
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.green.shade800),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _detailsTab(BuildContext context) {
    final irrigation =
        (predictionData['irrigation'] ?? {}) as Map<String, dynamic>;
    final yieldData = (predictionData['yield'] ?? {}) as Map<String, dynamic>;
    final fert = (predictionData['fertilizer'] ?? {}) as Map<String, dynamic>;
    final npkRequired =
        (fert['npk_required_per_hectare'] ?? {}) as Map<String, dynamic>;
    final List<dynamic> fertRecs =
        (fert['fertilizer_recommendations'] ?? []) as List<dynamic>;

    String _fmt(dynamic v, [String suffix = '']) =>
        v == null ? '-' : '$v$suffix';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- Irrigation summary cards ----------
          Text(
            t('Irrigation Summary', 'सिंचाई सारांश'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  t('Water (mm)', 'पानी (मि.मी.)'),
                  _fmt(irrigation['total_water_requirement_mm']),
                  Icons.opacity,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoCard(
                  t('Interval (days)', 'अंतराल (दिन)'),
                  _fmt(irrigation['irrigation_interval_days']),
                  Icons.schedule,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoCard(
                  t('Irrigations', 'सिंचाई की संख्या'),
                  _fmt(irrigation['estimated_number_of_irrigations']),
                  Icons.water_drop,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            t('Irrigation Schedule', 'सिंचाई अनुसूची'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            irrigation['irrigation_schedule'] ??
                t('Data not available', 'डेटा उपलब्ध नहीं'),
          ),
          const SizedBox(height: 8),
          Text(
            irrigation['water_source_recommendation'] ??
                t('Data not available', 'डेटा उपलब्ध नहीं'),
          ),

          const SizedBox(height: 20),

          // ---------- Yield section ----------
          Text(
            t('Yield Estimation', 'उपज अनुमान'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  t('Est. yield (kg/ha)', 'अनुमानित उपज (किग्रा/हे.)'),
                  _fmt(yieldData['estimated_yield_kg_per_hectare']),
                  Icons.agriculture,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoCard(
                  t('Quality', 'गुणवत्ता'),
                  yieldData['yield_quality']?.toString() ?? '-',
                  Icons.leaderboard,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoCard(
                  t('Confidence', 'विश्वास'),
                  yieldData['yield_confidence']?.toString() ?? '-',
                  Icons.check_circle_outline,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ---------- Fertilizer section ----------
          Text(
            t('Fertilizer Plan', 'उर्वरक योजना'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NutrientCircle(
                label: 'N',
                value: _fmt(npkRequired['nitrogen_kg'], ' kg/ha'),
              ),
              _NutrientCircle(
                label: 'P',
                value: _fmt(npkRequired['phosphorus_kg'], ' kg/ha'),
              ),
              _NutrientCircle(
                label: 'K',
                value: _fmt(npkRequired['potassium_kg'], ' kg/ha'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t('Recommended Fertilizers', 'अनुशंसित उर्वरक'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (fertRecs.isEmpty)
            Text(
              t('No fertilizer data available.', 'उर्वरक डेटा उपलब्ध नहीं है।'),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: fertRecs.map((e) => Text('• ${e.toString()}')).toList(),
            ),
        ],
      ),
    );
  }

  Widget _rotationTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('Secondary Crop (Rotation)', 'दूसरी फसल (रोटेशन)'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            t('Pea', 'मटर'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(t('Secondary Crop', 'द्वितीयक फसल')),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('Planting window', 'बोआई अवधि')),
                  const Text('15 Oct - 10 Nov'),
                  const SizedBox(height: 4),
                  Text(t('Season', 'सीज़न')),
                  const Text('Rabi'),
                  const SizedBox(height: 4),
                  Text(t('Ideal temp (°C)', 'उपयुक्त तापमान (°C)')),
                  const Text('10–15'),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('Ideal humidity (%)', 'उपयुक्त आर्द्रता (%)')),
                  const Text('20–30'),
                  const SizedBox(height: 4),
                  Text(t('Soil pH', 'मिट्टी pH')),
                  const Text('6.0–7.0'),
                  const SizedBox(height: 4),
                  Text(t('Water requirement', 'पानी आवश्यकता')),
                  const Text('25 mm/day'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            t('Purpose', 'उद्देश्य'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            t(
              '• Restore soil nitrogen\n• Requires less water',
              '• मिट्टी में नाइट्रोजन पुनः भरता है\n• कम पानी की ज़रूरत',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _NutrientCircle(label: 'N', value: '20 kg/ha'),
              _NutrientCircle(label: 'P', value: '40 kg/ha'),
              _NutrientCircle(label: 'K', value: '30 kg/ha'),
            ],
          ),
        ],
      ),
    );
  }
}

class _NutrientCircle extends StatelessWidget {
  final String label;
  final String value;

  const _NutrientCircle({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.green.shade100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.green.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }
}

// ========================================================
//                  DISEASE DETECTION + RESULT
// ========================================================

class DiseaseDetectionScreen extends StatefulWidget {
  const DiseaseDetectionScreen({super.key});

  @override
  State<DiseaseDetectionScreen> createState() => _DiseaseDetectionScreenState();
}

class _DiseaseDetectionScreenState extends State<DiseaseDetectionScreen> {
  File? selectedImage;
  final ImagePicker picker = ImagePicker();

  // ⚠️ IMPORTANT:
  // Change this BASE_URL depending on emulator / real phone usage.
  // For Android Emulator: "http://10.0.2.2:8000/api/leaf/predict-only"
  // For physical device: "http://192.168.2.76:8000/api/leaf/predict-only"
  // PC IP: 192.168.2.76 (Update this if your PC IP changes)
  static const String _apiUrl = "http://192.168.137.129:8000/disease_detection";

  Future<void> _pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => selectedImage = file);

    // after picking image -> upload to backend and open result page
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiseaseResultPage(imageFile: file, apiUrl: _apiUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: SafeArea(
        child: Column(
          children: [
            const GreenTopBar(
              titleEn: 'Disease Detection',
              titleHi: 'रोग पहचान',
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F6F6),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: selectedImage == null
                              ? Text(
                                  t(
                                    'Camera preview / image will appear here',
                                    'कैमरा प्रीव्यू / इमेज यहाँ दिखेगी',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.file(
                                    selectedImage!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.image),
                      ),
                      title: Text(
                        t('Image Disease Detected', 'इमेज रोग पहचान'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: selectedImage == null
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DiseaseResultPage(
                                    imageFile: selectedImage!,
                                    apiUrl: _apiUrl,
                                  ),
                                ),
                              );
                            },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FloatingActionButton(
                          heroTag: 'gallery',
                          onPressed: () => _pickImage(ImageSource.gallery),
                          child: const Icon(Icons.image),
                        ),
                        FloatingActionButton(
                          heroTag: 'camera',
                          onPressed: () => _pickImage(ImageSource.camera),
                          child: const Icon(Icons.camera_alt),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DiseaseResultPage extends StatefulWidget {
  final File imageFile;
  final String apiUrl;

  const DiseaseResultPage({
    super.key,
    required this.imageFile,
    required this.apiUrl,
  });

  @override
  State<DiseaseResultPage> createState() => _DiseaseResultPageState();
}

class _DiseaseResultPageState extends State<DiseaseResultPage> {
  bool isLoading = true;
  Map<String, dynamic>? diseaseData;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _uploadImage();
  }

  Future<void> _uploadImage() async {
    try {
      print('➡ Sending request to: ${widget.apiUrl}');
      print('➡ Image path: ${widget.imageFile.path}');

      final request = http.MultipartRequest('POST', Uri.parse(widget.apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath('file', widget.imageFile.path),
      );

      // Use a timeout so the UI doesn't hang indefinitely.
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );

      final status = streamedResponse.statusCode;
      final responseBody = await streamedResponse.stream.bytesToString();

      print('⬅ Response status: $status');
      print('⬅ Response body: $responseBody');

      if (!mounted) return;

      if (status == 200) {
        setState(() {
          diseaseData = jsonDecode(responseBody) as Map<String, dynamic>;
          isLoading = false;
          errorMessage = null;
        });
      } else {
        setState(() {
          errorMessage = 'Server error ($status)';
          isLoading = false;
        });
      }
    } on TimeoutException catch (_) {
      print('❌ Upload timeout');
      if (!mounted) return;
      setState(() {
        errorMessage = 'Request timed out — backend may be busy.';
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Request timed out. Try again.',
              'अनुरोध का समय समाप्त। कृपया पुनः प्रयास करें।',
            ),
          ),
        ),
      );
    } on SocketException catch (e) {
      print('❌ Socket error: $e');
      if (!mounted) return;
      setState(() {
        errorMessage = 'Network error: ${e.message}';
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Network error. Check connection or server.',
              'नेटवर्क त्रुटि। कनेक्शन या सर्वर जांचें।',
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ Upload error: $e');
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Error uploading image.', 'छवि अपलोड करने में त्रुटि।'),
          ),
        ),
      );
    }
  }

  // Future<void> _uploadImage() async {
  //   try {
  //     final request = http.MultipartRequest('POST', Uri.parse(widget.apiUrl));
  //     request.files.add(
  //       await http.MultipartFile.fromPath('file', widget.imageFile.path),
  //     );

  //     // Wait longer for the first prediction (model may be loading).
  //     final streamedResponse = await request.send().timeout(
  //       const Duration(seconds: 120),
  //     );
  //     final responseBody = await streamedResponse.stream.bytesToString();

  //     if (streamedResponse.statusCode == 200) {
  //       final jsonData = jsonDecode(responseBody);
  //       if (mounted) {
  //         setState(() {
  //           diseaseData = jsonData;
  //           isLoading = false;
  //         });
  //       }
  //     } else {
  //       if (mounted) {
  //         setState(() {
  //           errorMessage =
  //               'Backend returned error: ${streamedResponse.statusCode}';
  //           isLoading = false;
  //         });
  //       }
  //     }
  //   } on TimeoutException {
  //     if (mounted) {
  //       setState(() {
  //         errorMessage =
  //             'Request timed out — model may be loading. Try again in a few seconds.';
  //         isLoading = false;
  //       });
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() {
  //         errorMessage = 'Error: $e';
  //         isLoading = false;
  //       });
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: SafeArea(
        child: Column(
          children: [
            const GreenTopBar(
              titleEn: 'Disease Detection',
              titleHi: 'रोग पहचान',
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.green),
                      )
                    : errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text(t('Go Back', 'वापस जाएँ')),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildResultUI(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultUI(BuildContext context) {
    // Parse API response (supports new backend shape)
    final Map<String, dynamic> resp = diseaseData ?? {};
    final diseaseName =
        resp['predicted_label'] ?? resp['disease'] ?? 'Unknown Disease';
    // Confidence is a float like 0.306 -> show as percent
    final double confidenceNum = (resp['confidence'] is num)
        ? (resp['confidence'] as num).toDouble()
        : 0.0;
    final String confidencePct = '${(confidenceNum * 100).toStringAsFixed(1)}%';

    // recommendation block may contain cause, symptoms, treatment, prevention
    final rec = (resp['recommendation'] is Map)
        ? (resp['recommendation'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final String cause = rec['cause']?.toString() ?? '';
    final String symptoms = rec['symptoms']?.toString() ?? '';
    final List<dynamic> treatment = rec['treatment'] is List
        ? rec['treatment'] as List
        : [];
    final List<dynamic> prevention = rec['prevention'] is List
        ? rec['prevention'] as List
        : [];

    final overview = (cause.isNotEmpty || symptoms.isNotEmpty)
        ? (cause +
              (cause.isNotEmpty && symptoms.isNotEmpty ? '\n\n' : '') +
              symptoms)
        : (resp['overview']?.toString() ?? 'No information available');

    // For legacy compatibility map precautions to prevention list
    final precautions = prevention;

    // Derive a simple stage rating from confidence (1..5)
    final int stageRating = (confidenceNum <= 0)
        ? 3
        : ((confidenceNum * 5).clamp(1, 5).round());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9C4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    widget.imageFile,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        diseaseName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t(
                          'Confidence: $confidencePct',
                          'विश्वास: $confidencePct',
                        ),
                      ),
                      Text(t('Disease Stage:', 'रोग अवस्था:')),
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < stageRating
                                ? Icons.star
                                : Icons.star_border,
                            size: 18,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDE7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Overview:', 'सारांश:'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(overview),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDE7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Weather Conditions', 'मौसम की स्थिति'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.thermostat_outlined),
                        const SizedBox(height: 4),
                        Text(diseaseData?['ideal_temp'] ?? '60–70°F'),
                        Text(t('Temperature', 'तापमान')),
                      ],
                    ),
                    Column(
                      children: [
                        const Icon(Icons.water_drop_outlined),
                        const SizedBox(height: 4),
                        Text(diseaseData?['ideal_humidity'] ?? 'High'),
                        Text(t('Humidity', 'आर्द्रता')),
                      ],
                    ),
                    Column(
                      children: [
                        const Icon(Icons.science_outlined),
                        const SizedBox(height: 4),
                        Text(diseaseData?['ideal_ph'] ?? '6.0–7.0'),
                        const Text('pH'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      t('Precautions', 'सावधानियाँ'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Show prevention and treatment if available
                if (precautions.isNotEmpty || treatment.isNotEmpty)
                  Text(
                    [
                      if (precautions.isNotEmpty)
                        'Prevention:\n${precautions.map((e) => '- $e').join('\n')}',
                      if (treatment.isNotEmpty)
                        'Treatment:\n${treatment.map((e) => '- $e').join('\n')}',
                    ].join('\n\n'),
                  )
                else
                  Text('No specific precautions available.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================================
//                      COMMUNITY SCREEN
// ========================================================

// NOTE: This code assumes you already have:
//  - bool isEn;                         // global language flag
//  - String t(String en, String hi);    // translation helper
//  - GreenTopBar widget                 // your existing app bar



class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final SpeechToText stt = SpeechToText();

  bool listening = false;
  bool loading = true;

  List<dynamic> posts = [];

  // ================== API CALL ==================
  Future<void> fetchCommunityPosts() async {
    try {
      final response = await http.get(
        Uri.parse("${Secrets.communityBackendUrl}/posts"),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          setState(() {
            posts = decoded;
            loading = false;
          });
        } else {
          setState(() => loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid server response")),
          );
        }
      } else {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error ${response.statusCode}")),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: $e")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchCommunityPosts();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    stt.stop();
    super.dispose();
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              "Community",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // 🔍 Search
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: "Search...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            // 🟢 Posts Area
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: _buildPostsList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return const Center(child: Text("No posts available"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index] as Map<String, dynamic>;

        final name = post["username"] ?? "Unknown";
        final title = post["title"] ?? "";
        final content = post["content"] ?? "";
        final createdAt = post["created_at"] ?? "";

        final search = searchCtrl.text.toLowerCase();
        final combined = "$name $title $content".toLowerCase();

        if (search.isNotEmpty && !combined.contains(search)) {
          return const SizedBox();
        }

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(content),
                const SizedBox(height: 6),
                Text(
                  createdAt.toString(),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ========================================================
//                     MARKET PRICE SCREEN
// ========================================================

class MarketPriceScreen extends StatelessWidget {
  const MarketPriceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: SafeArea(
        child: Column(
          children: [
            const GreenTopBar(titleEn: 'Market Price', titleHi: 'बाज़ार भाव'),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: t('Search Here', 'यहाँ खोजें'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        t('Market Prices', 'बाज़ार मूल्य'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _marketTile('Wheat', '₹ 2485 / क्विंटल', '+5%'),
                    _marketTile('Sugar Cane', '₹ 340 / क्विंटल', '-2%'),
                    _marketTile('Corn', '₹ 2200 / क्विंटल', '+4%'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _marketTile(String name, String price, String change) {
    final positive = change.startsWith('+');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.rice_bowl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  price,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            change,
            style: TextStyle(
              color: positive ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================================
//                     NOTIFICATIONS SCREEN
// ========================================================

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: SafeArea(
        child: Column(
          children: [
            const GreenTopBar(titleEn: 'Notifications', titleHi: 'सूचनाएँ'),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    _notificationTile(
                      Icons.warning_amber,
                      t('Disease alert for Wheat', 'गेहूँ के लिए रोग चेतावनी'),
                      t(
                        'High humidity detected — check for leaf blight.',
                        'उच्च आर्द्रता पाई गई — लीफ ब्लाइट की जाँच करें।',
                      ),
                    ),
                    _notificationTile(
                      Icons.water_drop,
                      t('Irrigation required tomorrow', 'कल सिंचाई आवश्यक'),
                      t(
                        'Low moisture levels expected in your area.',
                        'आपके क्षेत्र में कम नमी की संभावना।',
                      ),
                    ),
                    _notificationTile(
                      Icons.price_change,
                      t('Market price increased', 'बाज़ार भाव बढ़ा'),
                      t(
                        'Wheat price increased by 5% today.',
                        'आज गेहूँ का भाव 5% बढ़ा।',
                      ),
                    ),
                    _notificationTile(
                      Icons.grass,
                      t('Fertilizer Reminder', 'उर्वरक रिमाइंडर'),
                      t(
                        'Apply Urea in the next 2 days for best results.',
                        'बेहतर परिणाम के लिए 2 दिनों में यूरिया डालें।',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBE7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: Colors.green.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================================
//                     PROFILE
// ========================================================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final nameCtrl = TextEditingController(text: "");
  final emailCtrl = TextEditingController(text: "");
  final mobileCtrl = TextEditingController(text: "");

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    mobileCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: Center(
        child: Container(
          width: size.width < 420 ? size.width * 0.95 : 420,
          height: size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Green header
              Container(
                height: 120,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00A651), Color(0xFF00C853)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        t('My Profile', 'मेरी प्रोफाइल'),
                        style: const TextStyle(
                          fontSize: 26,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 40,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      // Avatar with edit icon
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.grey.shade300,
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Name
                      _profileField(
                        icon: Icons.person_outline,
                        label: t('Name', 'नाम'),
                        controller: nameCtrl,
                      ),
                      const SizedBox(height: 16),

                      // Email instead of Aadhaar
                      _profileField(
                        icon: Icons.email_outlined,
                        label: t('Email', 'ईमेल'),
                        controller: emailCtrl,
                      ),
                      const SizedBox(height: 16),

                      // Mobile
                      _profileField(
                        icon: Icons.phone_android,
                        label: t('Mobile Number', 'मोबाइल नंबर'),
                        controller: mobileCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Settings row at bottom (like screenshot)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ListTile(
                          leading: const Icon(Icons.settings),
                          title: Text(
                            t('Settings', 'सेटिंग्स'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsPage(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _profileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _profileField({
    required this.icon,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: const Color(0xFFFFFBEA),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0C277)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFBFA233), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ========================================================
//                         SETTINGS SCREEN
// ========================================================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _languageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('Choose Language', 'भाषा चुनें')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<AppLang>(
              title: const Text('English'),
              value: AppLang.en,
              groupValue: appLang.value,
              onChanged: (v) {
                appLang.value = AppLang.en;
                Navigator.pop(context);
              },
            ),
            RadioListTile<AppLang>(
              title: const Text('हिंदी'),
              value: AppLang.hi,
              groupValue: appLang.value,
              onChanged: (v) {
                appLang.value = AppLang.hi;
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t('Coming soon', 'जल्द आ रहा है'))));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: Center(
        child: Container(
          width: size.width < 420 ? size.width * 0.95 : 420,
          height: size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00A651), Color(0xFF00C853)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        t('Settings', 'सेटिंग्स'),
                        style: const TextStyle(
                          fontSize: 26,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 40,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(
                        t('Update Your Profile', 'प्रोफाइल अपडेट करें'),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegistrationPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: Text(t('Language', 'भाषा')),
                      onTap: () => _languageDialog(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.key),
                      title: Text(t('Key Features', 'मुख्य विशेषताएँ')),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KeyFeaturesPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(
                        t(
                          'Ask to our AI chat bot',
                          'हमारे एआई चैटबॉट से पूछें',
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatBotScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: Text(
                        t('BirsaKisanDrishti FAQs', 'BirsaKisanDrishti FAQs'),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FaqsPage()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(t('About us', 'हमारे बारे में')),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutPage()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: Text(t('Logout', 'लॉगआउट')),
                      onTap: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (_) => false,
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(t('Delete Account', 'खाता हटाएँ')),
                      onTap: () => _comingSoon(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.feedback_outlined),
                      title: Text(t('Feedback', 'प्रतिक्रिया')),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FeedbackPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================================
//                        FAQs SCREEN
// ========================================================
class FaqsPage extends StatelessWidget {
  const FaqsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final List<Map<String, String>> faqs = [
      {
        'q_en': 'How does disease detection work?',
        'a_en':
            'Using AI image recognition, just click a clear photo of the disease-affected leaf. The app compares it with thousands of known images and detects the problem. It shows likely causes, suggested treatments, and basic prevention in simple language.',
        'q_hi': 'रोग का पता कैसे चलता है?',
        'a_hi':
            'AI इमेज रिकग्निशन का उपयोग करते हुए बस प्रभावित पत्ती की स्पष्ट फोटो लें। ऐप हजारों ज्ञात तस्वीरों से तुलना कर रोग का पता लगाता है और कारण, उपचार और रोकथाम को सरल भाषा में दिखाता है।',
      },
      {
        'q_en': 'How is water requirement calculated?',
        'a_en':
            'The app combines crop type, soil moisture, humidity, temperature, and rainfall data to estimate water requirement. It gives easy schedules like "water every 3 days".',
        'q_hi': 'पानी की आवश्यकता कैसे गणना की जाती है?',
        'a_hi':
            'ऐप फसल प्रकार, मिट्टी नमी, आर्द्रता, तापमान और वर्षा डेटा को मिलाकर पानी की आवश्यकता अनुमानित करता है और आसान सिंचाई शेड्यूल देता है जैसे "हर 3 दिन पानी दें"।',
      },
      {
        'q_en': 'Are market prices updated daily?',
        'a_en':
            'Yes. Market prices refresh multiple times a day using trusted government + mandi data sources so farmers can decide best time and place to sell.',
        'q_hi': 'क्या मार्केट कीमतें रोज अपडेट होती हैं?',
        'a_hi':
            'हाँ। सरकारी और मंडी डेटा स्रोतों से दिन में कई बार कीमतें अपडेट होती हैं ताकि किसान बेचने का सही समय और स्थान तय कर सकें।',
      },
      {
        'q_en': 'Does the app work offline?',
        'a_en':
            'Saved recommendations and last-viewed tips can be accessed without internet. New features update automatically when internet is back.',
        'q_hi': 'क्या ऐप ऑफलाइन चलता है?',
        'a_hi':
            'सहेजी गई अनुशंसाएँ और अंतिम देखी गई जानकारी बिना इंटरनेट के देखी जा सकती है। इंटरनेट आने पर फीचर्स अपने आप अपडेट होते हैं।',
      },
      {
        'q_en': 'Can farmers check government schemes?',
        'a_en':
            'Yes. The app lists major agriculture schemes, eligibility and benefits especially for small farmers.',
        'q_hi': 'क्या किसान सरकारी योजनाएँ देख सकते हैं?',
        'a_hi':
            'हाँ। ऐप प्रमुख कृषि योजनाएँ, पात्रता और लाभों की जानकारी देता है—विशेष रूप से छोटे किसानों के लिए।',
      },
      {
        'q_en': 'Is my data safe?',
        'a_en':
            'Yes. Only minimum information is stored to run the service. Data is never sold or shared with anyone.',
        'q_hi': 'क्या मेरा डेटा सुरक्षित है?',
        'a_hi':
            'हाँ। सेवा चलाने के लिए न्यूनतम जानकारी ही संग्रहीत की जाती है। डेटा कभी किसी के साथ साझा नहीं किया जाता।',
      },
      {
        'q_en': 'How can I use AI to predict crop yield?',
        'a_en':
            'AI uses soil history + climate data to show estimated yield range. It is guidance only—real yield depends on field practices and weather.',
        'q_hi': 'फसल उत्पादन का अनुमान AI कैसे लगाता है?',
        'a_hi':
            'AI मिट्टी के इतिहास और मौसम डेटा का उपयोग कर अनुमानित उत्पादन बताता है। यह केवल मार्गदर्शन है—वास्तविक उत्पादन खेत की स्थितियों और मौसम पर निर्भर है।',
      },
      {
        'q_en': 'Does the app support regional languages?',
        'a_en':
            'Yes! The app supports multiple Indian languages so farmers can read information in familiar script.',
        'q_hi': 'क्या ऐप क्षेत्रीय भाषाओं का समर्थन करता है?',
        'a_hi':
            'हाँ! ऐप कई भारतीय भाषाओं का समर्थन करता है ताकि किसान अपनी भाषा में जानकारी पढ़ सकें।',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: Center(
        child: Container(
          width: size.width < 420 ? size.width * 0.95 : 420,
          height: size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Column(
            children: [
              Container(
                height: 110,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00A651), Color(0xFF00C853)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        t('FAQs', 'अक्सर पूछे जाने वाले प्रश्न'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 36,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: ListView.builder(
                    itemCount: faqs.length,
                    itemBuilder: (_, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t(faqs[index]['q_en']!, faqs[index]['q_hi']!),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t(faqs[index]['a_en']!, faqs[index]['a_hi']!),
                              style: const TextStyle(fontSize: 13, height: 1.3),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t(
                  'Made With 💚 For Smart India Hackathon 2025',
                  'स्मार्ट इंडिया हैकथॉन 2025 के लिए प्यार से बनाया गया 💚',
                ),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================================
//                   KEY FEATURES SCREEN
// ========================================================

// ======================== KEY FEATURES SCREEN ========================
class KeyFeaturesPage extends StatelessWidget {
  const KeyFeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final List<Map<String, dynamic>> features = [
      {
        'title_en': 'Crop Recommendation',
        'title_hi': 'फसल सुझाव',
        'desc_en': 'AI-based crop suggestion using soil & weather',
        'desc_hi': 'मिट्टी और मौसम के आधार पर AI फसल सुझाव',
        'icon': Icons.grass,
      },
      {
        'title_en': 'Disease Detection',
        'title_hi': 'रोग पहचान',
        'desc_en': 'Scan plant leaves for instant disease diagnosis',
        'desc_hi': 'पत्ती स्कैन कर रोग की तुरंत पहचान',
        'icon': Icons.search,
      },
      {
        'title_en': 'Water Requirement',
        'title_hi': 'पानी की आवश्यकता',
        'desc_en': 'Shows irrigation requirement for selected crop',
        'desc_hi': 'चुनी हुई फसल के लिए सिंचाई आवश्यकता बताता है',
        'icon': Icons.water_drop,
      },
      {
        'title_en': 'Weather Forecast',
        'title_hi': 'मौसम पूर्वानुमान',
        'desc_en': 'Smart weather insights for planning',
        'desc_hi': 'बेहतर योजना के लिए स्मार्ट मौसम जानकारियाँ',
        'icon': Icons.cloud,
      },
      {
        'title_en': 'Market Price Insight',
        'title_hi': 'बाजार मूल्य जानकारी',
        'desc_en': 'Real-time mandi price trends',
        'desc_hi': 'रियल टाइम मंडी कीमतें',
        'icon': Icons.show_chart,
      },
      {
        'title_en': 'Government Schemes',
        'title_hi': 'सरकारी योजनाएँ',
        'desc_en': 'List of schemes + eligibility + apply links',
        'desc_hi': 'योजनाओं की सूची + पात्रता + आवेदन लिंक',
        'icon': Icons.account_balance,
      },
      {
        'title_en': 'Seasonal Crop Calendar',
        'title_hi': 'मौसमी फसल कैलेंडर',
        'desc_en': 'Month wise sowing & harvesting schedule',
        'desc_hi': 'महीनेवार बुवाई और कटाई समय सारणी',
        'icon': Icons.calendar_month,
      },
      {
        'title_en': 'Farming Task Reminder',
        'title_hi': 'खेती कार्य रिमाइंडर',
        'desc_en': 'Watering & irrigation notifications',
        'desc_hi': 'सिंचाई और पानी देने के लिए नोटिफिकेशन',
        'icon': Icons.notifications_active,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: Center(
        child: Container(
          width: size.width < 420 ? size.width * 0.95 : 420,
          height: size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Column(
            children: [
              Container(
                height: 110,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00A651), Color(0xFF00C853)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        t('Key Features', 'मुख्य विशेषताएँ'),
                        style: const TextStyle(
                          fontSize: 26,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 36,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'BirsaKisanDrishti',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t(
                              'AI powered assistant to improve your crop yield.',
                              'आपकी फसल उत्पादन बढ़ाने के लिए AI सहायक।',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      t('Smart Farming Features', 'स्मार्ट खेती सुविधाएँ'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 1.35,
                          ),
                      itemCount: features.length,
                      itemBuilder: (_, index) {
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 3,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Icon(
                                features[index]['icon'],
                                size: 38,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t(
                                  features[index]['title_en']!,
                                  features[index]['title_hi']!,
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t(
                                  features[index]['desc_en']!,
                                  features[index]['desc_hi']!,
                                ),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================================
//                      ABOUT US SCREEN
// ========================================================

// ======================== ABOUT US SCREEN ========================
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: Center(
        child: Container(
          width: size.width < 420 ? size.width * 0.95 : 420,
          height: size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Column(
            children: [
              Container(
                height: 110,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00A651), Color(0xFF00C853)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        t('About Us', 'हमारे बारे में'),
                        style: const TextStyle(
                          fontSize: 26,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 36,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'BirsaKisanDrishti',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.green.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t(
                                '-Your Smart Farming Companion',
                                '-आपका स्मार्ट खेती साथी',
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      Text(
                        t(
                          'BirsaKisanDrishti is an AI-powered farming assistant that helps farmers make smarter decisions. Our mission is to boost crop yield, maximize profit, and simplify farming through technology.',
                          'BirsaKisanDrishti एक AI-संचालित खेती सहायक है जो किसानों को स्मार्ट निर्णय लेने में मदद करता है। हमारा मिशन फसल उत्पादन बढ़ाना, लाभ अधिक करना और तकनीक के माध्यम से खेती को सरल बनाना है।',
                        ),
                        style: const TextStyle(fontSize: 14, height: 1.35),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        t('What We Provide', 'हम क्या प्रदान करते हैं'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(height: 14),

                      _infoItem(
                        'Smart Crop Recommendation',
                        'स्मार्ट फसल सुझाव',
                        Icons.forest,
                      ),
                      _infoItem(
                        'Satellite Based Soil Insights',
                        'उपग्रह आधारित मिट्टी अंतर्दृष्टि',
                        Icons.satellite_alt,
                      ),
                      _infoItem(
                        'AI Farming Assistance',
                        'AI खेती सहायता',
                        Icons.auto_awesome,
                      ),
                      _infoItem(
                        'Fertilizer Recommendation',
                        'उर्वरक अनुशंसा',
                        Icons.grass,
                      ),
                      _infoItem(
                        'Yield Production',
                        'उत्पादन पूर्वानुमान',
                        Icons.trending_up,
                      ),
                      _infoItem(
                        'Weather Based Soil Insights',
                        'मौसम आधारित मिट्टी अंतर्दृष्टि',
                        Icons.cloud,
                      ),

                      const SizedBox(height: 24),
                      Text(
                        t('Our Mission', 'हमारा मिशन'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.eco, color: Colors.green, size: 24),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t(
                                'Empowering every farmer with AI-driven knowledge to increase productivity and sustainability.',
                                'प्रत्येक किसान को AI आधारित ज्ञान के साथ सशक्त करना ताकि उत्पादकता और स्थिरता बढ़ सके।',
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Center(
                        child: Text(
                          t(
                            'Made With 💚 For Smart India Hackathon 2025',
                            'स्मार्ट इंडिया हैकथॉन 2025 के लिए प्यार से बनाया गया 💚',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _infoItem(String en, String hi, IconData icon) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, color: Colors.green.shade800),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            t(en, hi),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
      ],
    ),
  );
}

// ========================================================
//                     KRISHIMITRA SCREEN
// ========================================================

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController messageCtrl = TextEditingController();
  final List<Map<String, dynamic>> messages = [];

  final SpeechToText stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final ApiService api = ApiService();

  bool listening = false;

  // 🔊 Text-to-Speech
  Future<void> _speak(String text) async {
    final langCode = isEn ? 'en-IN' : 'hi-IN'; // auto language
    await _tts.setLanguage(langCode);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45);
    await _tts.stop();
    await _tts.speak(text);
  }

  // 🧠 Send message to backend & speak reply
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      messages.add({"sender": "user", "text": text});
    });
    messageCtrl.clear();

    try {
      final language = isEn ? "english" : "hindi";
      final reply = await api.sendChatMessage(
        userId: "demo",
        message: text,
        language: language,
      );

      if (mounted) {
        setState(() {
          messages.add({"sender": "bot", "text": reply});
        });
      }

      await _speak(reply); // 🔊 auto-speak bot reply
    } catch (e) {
      final errorText = "Error: ${e.toString()}";
      if (mounted) {
        setState(() {
          messages.add({"sender": "bot", "text": errorText});
        });
      }
      await _speak(errorText); // speak the error also
    }
  }

  // 🎤 Voice input
  Future<void> _startVoice() async {
    bool available = await stt.initialize();
    if (!available) return;
    setState(() => listening = true);

    stt.listen(
      onResult: (result) {
        messageCtrl.text = result.recognizedWords;
      },
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 3),
    );

    Future.delayed(const Duration(seconds: 6), () async {
      setState(() => listening = false);
      await stt.stop();
    });
  }

  // 🧹 Cleanup
  @override
  void dispose() {
    messageCtrl.dispose();
    stt.stop();
    _tts.stop();
    super.dispose();
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: SafeArea(
        child: Column(
          children: [
            const GreenTopBar(titleEn: "KrishiMitra", titleHi: "कृषिमित्र"),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isUser = msg["sender"] == "user";

                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Colors.green.shade200
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isUser)
                              IconButton(
                                icon: const Icon(Icons.volume_up, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _speak(msg["text"]),
                              ),
                            const SizedBox(width: 6),
                            Flexible(child: Text(msg["text"])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      listening ? Icons.mic : Icons.mic_none,
                      color: listening ? Colors.red : Colors.green,
                    ),
                    onPressed: _startVoice,
                  ),
                  Expanded(
                    child: TextField(
                      controller: messageCtrl,
                      decoration: InputDecoration(
                        hintText: t("Type here...", "यहाँ लिखें..."),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.green),
                    onPressed: () => _sendMessage(messageCtrl.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================================
//                     FEEDBACK PAGE
// ========================================================

// ===================== FEEDBACK PAGE =====================
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  int rating = 0;
  final feedbackCtrl = TextEditingController();
  final int maxChars = 500;

  @override
  void dispose() {
    feedbackCtrl.dispose();
    super.dispose();
  }

  void _showSubmittedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFB9FF9C),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('Feedback Submitted', 'प्रतिक्रिया सबमिट हुई'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t(
                  'Your feedback is successfully submitted. We respect and care about your feedback. Our team will look into it.',
                  'आपकी प्रतिक्रिया सफलतापूर्वक सबमिट हो गई है। हम आपकी प्रतिक्रिया का सम्मान करते हैं। हमारी टीम इसे देखेगी।',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A651),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context); // go back screen
                  },
                  child: Text(
                    t('GO BACK', 'वापस जाएँ'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (rating == 0 || feedbackCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Please give rating and feedback',
              'कृपया रेटिंग और प्रतिक्रिया दें',
            ),
          ),
        ),
      );
      return;
    }
    // here you could send to backend
    _showSubmittedDialog();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: Center(
        child: Container(
          width: size.width < 420 ? size.width * 0.95 : 420,
          height: size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00A651), Color(0xFF00C853)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        t('Feedback', 'प्रतिक्रिया'),
                        style: const TextStyle(
                          fontSize: 26,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 40,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(
                          'We would love to hear your feedback',
                          'हम आपकी प्रतिक्रिया सुनना पसंद करेंगे',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t(
                          'Help us to improve your experience',
                          'अपने अनुभव को बेहतर करने में हमारी मदद करें',
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        t(
                          'We care your experience',
                          'हम आपके अनुभव की परवाह करते हैं',
                        ),
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        t('How Would You Rate Us?', 'आप हमें कैसे रेट करेंगे?'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (index) {
                          final filled = rating >= index + 1;
                          return IconButton(
                            onPressed: () {
                              setState(() => rating = index + 1);
                            },
                            icon: Icon(
                              Icons.eco,
                              size: 30,
                              color: filled
                                  ? const Color(0xFF00A651)
                                  : Colors.grey.shade400,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t('Share Your Thoughts', 'अपने विचार साझा करें'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEFEF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: TextField(
                          controller: feedbackCtrl,
                          maxLength: maxChars,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            counterText: "",
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${feedbackCtrl.text.length}/$maxChars',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006837),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: _submit,
                          child: Text(
                            t('Submit Feedback', 'प्रतिक्रिया सबमिट करें'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================================
//                   REGISTRATION PAGE
// ========================================================
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final farmSizeCtrl = TextEditingController();
  final soilTypeCtrl = TextEditingController();

  String? userType; // <-- NEW
  String? gender;
  String? educationLevel;
  String? irrigationMethod;

  final List<String> genderOptions = ['Male', 'Female', 'Others'];
  final List<String> educationOptions = [
    'Primary',
    'Metric',
    'Intermediate',
    'Graduate',
    "Can\'t Say",
  ];
  final List<String> irrigationOptions = [
    'Drip irrigation',
    'Sprinkler irrigation',
    'Surface irrigation',
  ];
  final List<String> userTypeOptions = ['Researcher', 'Farmer'];

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    ageCtrl.dispose();
    farmSizeCtrl.dispose();
    soilTypeCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String en, String hi) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t(en, hi))));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // TODO: send data to backend here
    _showSnack(
      'Profile updated successfully (demo)',
      'प्रोफाइल सफलतापूर्वक अपडेट हो गई (डेमो)',
    );

    // If you want to go back after update:
    // Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFAED581),
      body: Center(
        child: Container(
          width: size.width < 420 ? size.width * 0.95 : 420,
          height: size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Green header
              Container(
                height: 110,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00A651), Color(0xFF00C853)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        t('Registration Page', 'पंजीकरण पेज'),
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 36,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Form content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('Complete your profile', 'अपनी प्रोफाइल पूरी करें'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            text: t('Account Status: ', 'खाता स्थिति: '),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: t('Active', 'सक्रिय'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t(
                            'Update Your Basic Info:',
                            'अपनी बुनियादी जानकारी अपडेट करें:',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),

                        // Are you? (Researcher / Farmer)
                        _label(t('Are you?', 'आप हैं?')),
                        DropdownButtonFormField<String>(
                          value: userType,
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFEFEFEF),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: userTypeOptions
                              .map(
                                (u) =>
                                    DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                          onChanged: (val) => setState(() => userType = val),
                          validator: (v) => v == null || v.isEmpty
                              ? t('Select your role', 'अपनी भूमिका चुनें')
                              : null,
                        ),
                        const SizedBox(height: 10),

                        // First Name
                        _label(t('First Name', 'पहला नाम')),
                        TextFormField(
                          controller: firstNameCtrl,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? t('Enter first name', 'पहला नाम दर्ज करें')
                              : null,
                        ),

                        const SizedBox(height: 10),

                        // Last Name
                        _label(t('Last Name', 'अंतिम नाम')),
                        TextFormField(
                          controller: lastNameCtrl,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? t('Enter last name', 'अंतिम नाम दर्ज करें')
                              : null,
                        ),
                        const SizedBox(height: 10),

                        // Age
                        _label(t('Age', 'आयु')),
                        TextFormField(
                          controller: ageCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: (v) => v == null || v.isEmpty
                              ? t('Enter age', 'आयु दर्ज करें')
                              : null,
                        ),
                        const SizedBox(height: 10),

                        // Gender
                        _label(t('Gender', 'लिंग')),
                        DropdownButtonFormField<String>(
                          value: gender,
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFEFEFEF),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: genderOptions
                              .map(
                                (g) =>
                                    DropdownMenuItem(value: g, child: Text(g)),
                              )
                              .toList(),
                          onChanged: (val) => setState(() => gender = val),
                          validator: (v) => v == null || v.isEmpty
                              ? t('Select gender', 'लिंग चुनें')
                              : null,
                        ),
                        const SizedBox(height: 10),

                        // Education level
                        _label(t('Education level', 'शिक्षा स्तर')),
                        DropdownButtonFormField<String>(
                          value: educationLevel,
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFEFEFEF),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: educationOptions
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => educationLevel = val),
                          validator: (v) => v == null || v.isEmpty
                              ? t('Select education level', 'शिक्षा स्तर चुनें')
                              : null,
                        ),

                        const SizedBox(height: 18),
                        Text(
                          t(
                            'Update Your Farm Info:',
                            'अपनी खेती की जानकारी अपडेट करें:',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),

                        // Farm size
                        _label(
                          t('Farm Size (in ha)', 'खेत का आकार (हेक्टेयर में)'),
                        ),
                        TextFormField(
                          controller: farmSizeCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? t('Enter farm size', 'खेत का आकार दर्ज करें')
                              : null,
                        ),
                        const SizedBox(height: 10),

                        // Soil type
                        _label(t('Soil Type', 'मिट्टी का प्रकार')),
                        TextFormField(
                          controller: soilTypeCtrl,
                          validator: (v) => v == null || v.isEmpty
                              ? t(
                                  'Enter soil type',
                                  'मिट्टी का प्रकार दर्ज करें',
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),

                        // Irrigation method
                        _label(t('Irrigation Method', 'सिंचाई की विधि')),
                        DropdownButtonFormField<String>(
                          value: irrigationMethod,
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFEFEFEF),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: irrigationOptions
                              .map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => irrigationMethod = val),
                          validator: (v) => v == null || v.isEmpty
                              ? t(
                                  'Select irrigation method',
                                  'सिंचाई की विधि चुनें',
                                )
                              : null,
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF006837),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            onPressed: _submit,
                            child: Text(
                              t('Update Profile', 'प्रोफाइल अपडेट करें'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// small label helper
Widget _label(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}

// ========================================================
//                     MY FARM PAGE
// ========================================================

class MyFarmPage extends StatelessWidget {
  const MyFarmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff2fdf2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Text(
                    "My Farm",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Farm Location Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Farm Location",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text("Dhanbad, Jharkhand\nVillage: Bhadra, Block XYZ"),
                    SizedBox(height: 4),
                    Text("Total Area: 3.5 ha"),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Current Season Crop
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          "Current Season Crop",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Chip(
                          label: Text("In Progress"),
                          backgroundColor: Colors.green,
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Wheat on 3.5 ha",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Sown: 15 Nov 2025 | Expected Harvest: 10 Mar 2025",
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        "View AI Recommendation For This Field",
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Past Crop + Personalized Recommendation
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Past Crop Data",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text("Rabi 2023-24  • Wheat  • 18 q/h"),
                          Text("Kharif 2023   • Paddy  • 55 q/h"),
                          Text("Rabi 2022-23  • Chickpea  • 12 q/h"),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Recommendation",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text("Next Crop: Chickpea (Gram)"),
                          SizedBox(height: 6),
                          Text("• Improves soil nitrogen"),
                          Text("• Requires less water than Wheat"),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================================
//                    PROFILE PAGE
// ========================================================

// ========================================================
//                     END OF MAIN.DART
// ========================================================
