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

// HOME SCREEN

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

  @override
  void initState() {
    super.initState();
    _loadAlarmSettings();
  }

  Future<void> _loadAlarmSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      for (final prayer in prayers) {
        final name = prayer['name']!;
        alarms[name] = prefs.getBool('alarm_$name') ?? alarms[name]!;
      }
    });
  }

  Future<void> _toggleAlarm(String name, bool value) async {
    setState(() => alarms[name] = value);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarm_$name', value);
  }

  void _openPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Namaz Alarm',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openPage(const SettingsScreen()),
          ),
        ],
      ),
      body: IndexedStack(
        index: selectedTab,
        children: [
          _buildHome(),
          const ToolsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mosque_outlined),
            selectedIcon: Icon(Icons.mosque),
            label: 'Prayer',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman),
            label: 'Tools',
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [green, darkGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.nights_stay, color: gold, size: 38),
              SizedBox(height: 16),
              Text(
                'Stay consistent.\nNever miss your Salah.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Build a better morning routine with Namaz Alarm.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Prayer reminders',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: darkGreen,
          ),
        ),
        const SizedBox(height: 12),
        ...prayers.map((prayer) {
          final name = prayer['name']!;

          return Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: green.withValues(alpha: 0.08)),
            ),
            child: ListTile(
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.access_time, color: green),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(prayer['time']!),
              trailing: Switch(
                value: alarms[name] ?? false,
                activeTrackColor: green,
                onChanged: (value) => _toggleAlarm(name, value),
              ),
            ),
          );
        }),
        const SizedBox(height: 18),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: () => _openPage(const AlarmChallengeScreen()),
            icon: const Icon(Icons.alarm),
            label: const Text('Try Alarm Challenge'),
            style: FilledButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Note: Prayer times shown here are sample times. '
          'Automatic alarms and local prayer-time calculations '
          'are not configured in this version.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }
}

// TOOLS SCREEN

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Alarm tools',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: darkGreen,
          ),
        ),
        const SizedBox(height: 16),
        _toolCard(
          icon: Icons.face,
          title: 'Face detection',
          subtitle: 'Check for a face using your camera.',
          onTap: () => _open(
            context,
            const RealFaceDetectionScreen(),
          ),
        ),
        _toolCard(
          icon: Icons.qr_code,
          title: 'Washroom QR generator',
          subtitle: 'Create and share your challenge QR code.',
          onTap: () => _open(
            context,
            const WashroomQrGeneratorScreen(),
          ),
        ),
        _toolCard(
          icon: Icons.qr_code_scanner,
          title: 'Scan washroom QR',
          subtitle: 'Scan the saved QR code to finish a challenge.',
          onTap: () => _open(
            context,
            const WashroomQrScannerScreen(),
          ),
        ),
        _toolCard(
          icon: Icons.settings,
          title: 'Settings',
          subtitle: 'Choose an alarm sound.',
          onTap: () => _open(context, const SettingsScreen()),
        ),
      ],
    );
  }

  Widget _toolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: green.withValues(alpha: 0.10),
          child: Icon(icon, color: green),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ALARM CHALLENGE: FACE DETECTION FIRST, THEN QR SCANNING

class AlarmChallengeScreen extends StatelessWidget {
  const AlarmChallengeScreen({super.key});

  Future<void> _startChallenge(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RealFaceDetectionScreen(
          continueToQr: true,
        ),
      ),
    );

    if (!context.mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge completed!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wake-up Challenge')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wb_sunny_outlined, size: 80, color: gold),
              const SizedBox(height: 20),
              const Text(
                'Good morning!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Complete both steps to finish your wake-up challenge.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _challengeStep(
                icon: Icons.face,
                title: 'Step 1: Face detection',
                subtitle: 'Show your face to the camera.',
              ),
              const SizedBox(height: 12),
              _challengeStep(
                icon: Icons.qr_code_scanner,
                title: 'Step 2: Scan the QR code',
                subtitle: 'Go to your washroom and scan its QR code.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () => _startChallenge(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Start Challenge'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _challengeStep({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: green, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// SETTINGS

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _soundPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSound();
  }

  Future<void> _loadSound() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _soundPath = prefs.getString('custom_alarm_sound');
      _loading = false;
    });
  }

  Future<void> _chooseSound() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;

      if (path == null) {
        _showMessage('This audio file cannot be accessed.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_alarm_sound', path);

      if (!mounted) return;

      setState(() => _soundPath = path);
      _showMessage('Custom alarm sound saved.');
    } catch (e) {
      _showMessage('Could not select the audio file.');
    }
  }

  Future<void> _previewSound() async {
    if (_soundPath == null) {
      _showMessage('Choose an alarm sound first.');
      return;
    }

    try {
      await _player.stop();
      await _player.play(DeviceFileSource(_soundPath!));
    } catch (e) {
      _showMessage('Could not play this audio file.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 60,
                  color: green,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Alarm sound',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose an audio file from your device and preview it.',
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.music_note, color: green),
                    title: const Text('Selected sound'),
                    subtitle: Text(
                      _soundPath == null
                          ? 'No custom sound selected'
                          : _soundPath!.split('/').last,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _chooseSound,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Choose Audio File'),
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _previewSound,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Preview Sound'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Important: selecting a sound saves your preference, '
                  'but this screen does not schedule or trigger alarms '
                  'in the background.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
    );
  }
}
