import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'real_tools.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NamazAlarmApp());
}

const Color green = Color(0xFF075442);
const Color darkGreen = Color(0xFF063C32);
const Color gold = Color(0xFFC5A04A);
const Color cream = Color(0xFFFFFCF4);

class NamazAlarmApp extends StatelessWidget {
  const NamazAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Namaz Alarm',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          primary: green,
          secondary: gold,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: cream,
          foregroundColor: darkGreen,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// --------------------------------------------------
// HOME SCREEN
// --------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTab = 0;

  final List<Map<String, String>> prayers = [
    {'name': 'Fajr', 'time': '05:10 AM'},
    {'name': 'Dhuhr', 'time': '12:24 PM'},
    {'name': 'Asr', 'time': '03:42 PM'},
    {'name': 'Maghrib', 'time': '06:12 PM'},
    {'name': 'Isha', 'time': '07:24 PM'},
  ];

  final Map<String, bool> alarms = {
    'Fajr': true,
    'Dhuhr': false,
    'Asr': false,
    'Maghrib': false,
    'Isha': false,
  };

  void openAlarmChallenge() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AlarmChallengeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title
