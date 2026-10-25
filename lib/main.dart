import 'package:flutter/material.dart';

void main() {
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
        title: const Text(
          '☾ Namaz Alarm',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 25,
            color: darkGreen,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: selectedTab,
        children: [
          buildHome(),
          buildPrayerTimes(),
          const ToolsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        indicatorColor: const Color(0xFFDCEBE1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.access_time),
            label: 'Prayer Times',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view),
            label: 'Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget buildHome() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Assalamu Alaikum 👋',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: darkGreen,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Start your day with Salah.',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 22),

        // Next prayer card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [darkGreen, green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: green.withValues(alpha: 0.18),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.mosque,
                color: gold,
                size: 38,
              ),
              SizedBox(height: 15),
              Text(
                'NEXT PRAYER',
                style: TextStyle(
                  color: Colors.white70,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Fajr',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '05:10 AM',
                style: TextStyle(
                  color: Color(0xFFFFDF94),
                  fontSize: 27,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Prepare your heart for prayer.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Prayer Schedule',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => selectedTab = 1);
              },
              child: const Text('View all'),
            ),
          ],
        ),

        ...prayers.map((prayer) {
          final name = prayer['name']!;

          return Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFEDE6D5)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE2EEE5),
                child: Icon(
                  name == 'Fajr'
                      ? Icons.nightlight_round
                      : Icons.wb_sunny_outlined,
                  color: green,
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(prayer['time']!),
              trailing: Switch(
                value: alarms[name] ?? false,
                activeTrackColor: green,
                onChanged: (value) {
                  setState(() => alarms[name] = value);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$name alarm ${value ? 'enabled' : 'disabled'} '
                        '(demo only)',
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        // Try the challenge flow
        SizedBox(
          height: 58,
          child: FilledButton.icon(
            onPressed: openAlarmChallenge,
            icon: const Icon(Icons.notifications_active),
            label: const Text(
              'Try Fajr Alarm Challenge',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          ),
        ),

        const SizedBox(height: 26),

        const Text(
          'Quick Tools',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: darkGreen,
          ),
        ),
        const SizedBox(height: 14),

        const Row(
          children: [
            Expanded(
              child: ToolCard(
                icon: Icons.explore,
                title: 'Qibla',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ToolCard(
                icon: Icons.fingerprint,
                title: 'Tasbeeh',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: ToolCard(
                icon: Icons.menu_book,
                title: 'Daily Dua',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ToolCard(
                icon: Icons.check_circle_outline,
                title: 'Prayer Tracker',
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget buildPrayerTimes() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Prayer Times',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
            color: darkGreen,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Daily prayer schedule'),
        const SizedBox(height: 20),
        ...prayers.map(
          (p) => Card(
            child: ListTile(
              leading: const Icon(Icons.mosque, color: green),
              title: Text(p['name']!),
              trailing: Text(
                p['time']!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Demo times only. Real prayer times must be calculated '
          'for your location and date.',
        ),
      ],
    );
  }
}

class ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const ToolCard({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE6D5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: green, size: 32),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class AlarmChallengeScreen extends StatefulWidget {
  const AlarmChallengeScreen({super.key});

  @override
  State<AlarmChallengeScreen> createState() =>
      _AlarmChallengeScreenState();
}

class _AlarmChallengeScreenState extends State<AlarmChallengeScreen> {
  bool faceVerified = false;
  bool codeAccepted = false;

  final TextEditingController codeController = TextEditingController();

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkGreen,
      appBar: AppBar(
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        title: const Text('Fajr Wake-up Challenge'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.notifications_active,
              color: gold,
              size: 70,
            ),
            const SizedBox(height: 18),
            const Text(
              'Time to Wake Up',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Complete your wake-up challenge to dismiss '
              'the demonstration alarm.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 35),

            // Step 1: Face verification demo
            challengeCard(
              number: '1',
              title: 'Face Verification',
              description: faceVerified
                  ? 'Verification demo completed.'
                  : 'Stand up and look at the camera.',
              icon: Icons.face_retouching_natural,
              completed: faceVerified,
              buttonText: faceVerified
                  ? 'Verified'
                  : 'Simulate Face Verification',
              onPressed: faceVerified
                  ? null
                  : () {
                      setState(() => faceVerified = true);
                      showMessage(
                        'Demo verification complete. '
                        'Real camera detection is not connected yet.',
                      );
                    },
            ),

            const SizedBox(height: 18),

            // Step 2: Washroom code demo
            challengeCard(
              number: '2',
              title: 'Washroom QR Challenge',
              description: faceVerified
                  ? 'Enter the demo code displayed in your washroom.'
                  : 'Complete face verification first.',
              icon: Icons.qr_code_scanner,
              completed: codeAccepted,
              buttonText: codeAccepted
                  ? 'Code Accepted'
                  : 'Verify Washroom Code',
              onPressed: !faceVerified || codeAccepted
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Washroom Code'),
                          content: TextField(
                            controller: codeController,
                            decoration: const InputDecoration(
                              hintText: 'Enter your code',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                              },
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () {
                                if (codeController.text.trim() ==
                                    'WASHROOM-001') {
                                  setState(() => codeAccepted = true);
                                  Navigator.pop(dialogContext);
                                  showMessage('Demo code accepted.');
                                } else {
                                  showMessage('Incorrect demo code.');
                                }
                              },
                              child: const Text('Verify'),
                            ),
                          ],
                        ),
                      );
                    },
            ),

            const SizedBox(height: 28),

            FilledButton.icon(
              onPressed: codeAccepted
                  ? () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Challenge Complete'),
                          content: const Text(
                            'You completed the demonstration. '
                            'You can now prepare for Salah.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(this.context);
                              },
                              child: const Text('Finish'),
                            ),
                          ],
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.check_circle),
              label: const Text('Complete Challenge'),
              style: FilledButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: darkGreen,
                padding: const EdgeInsets.all(17),
              ),
            ),

            const SizedBox(height: 20),

            // Always retain an emergency exit in a real implementation.
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Emergency Exit'),
                    content: const Text(
                      'This demonstration has no active alarm. '
                      'A production version should always provide '
                      'an accessible emergency way to stop an alarm.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Navigator.pop(context);
                        },
                        child: const Text('Exit Demo'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text(
                'Emergency Exit',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget challengeCard({
    required String number,
    required String title,
    required String description,
    required IconData icon,
    required bool completed,
    required String buttonText,
    required VoidCallback? onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE2EEE5),
                child: Icon(icon, color: green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$number. $title',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: darkGreen,
                  ),
                ),
              ),
              if (completed)
                const Icon(Icons.check_circle, color: green),
            ],
          ),
          const SizedBox(height: 12),
          Text(description),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = [
      ['Qibla', Icons.explore],
      ['Tasbeeh', Icons.fingerprint],
      ['Daily Dua', Icons.menu_book],
      ['Prayer Tracker', Icons.check_circle_outline],
      ['Hijri Calendar', Icons.calendar_month],
      ['Washroom QR', Icons.qr_code],
    ];

    return Scaffold(
      backgroundColor: cream,
      body: GridView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: tools.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
        ),
        itemBuilder: (context, index) {
          return ToolCard(
            icon: tools[index][1] as IconData,
            title: tools[index][0] as String,
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = [
      ['Prayer Times', Icons.access_time],
      ['Alarm Sound', Icons.music_note],
      ['Face Verification', Icons.face],
      ['Washroom QR Setup', Icons.qr_code],
      ['Location', Icons.location_on],
      ['Notifications', Icons.notifications],
      ['About Namaz Alarm', Icons.info_outline],
    ];

    return Scaffold(
      backgroundColor: cream,
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 16),
          ...settings.map(
            (item) => Card(
              color: Colors.white,
              elevation: 0,
              child: ListTile(
                leading: Icon(item[1] as IconData, color: green),
                title: Text(item[0] as String),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${item[0]} settings will be implemented next.',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
