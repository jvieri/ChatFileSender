import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'di/injection.dart';
import 'domain/entities/chat_message.dart';
import 'presentation/bloc/chat_bloc.dart';
import 'presentation/bloc/file_upload_bloc.dart';
import 'presentation/screens/chat_screen.dart';
import 'presentation/screens/user_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ChatBloc>(create: (_) => sl<ChatBloc>()),
        BlocProvider<FileUploadBloc>(create: (_) => sl<FileUploadBloc>()),
      ],
      child: MaterialApp(
        title: 'Chat with Files',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const _StartupRouter(),
        routes: {
          '/home': (_) => const HomeScreen(),
          '/select-user': (_) => const UserSelectionScreen(),
        },
      ),
    );
  }
}

/// Reads SharedPreferences and decides whether to show user selection or home.
class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('current_user_id');
    final savedName = prefs.getString('current_user_name');

    if (savedId != null && savedName != null) {
      ChatMessage.currentUserId = savedId;
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo users catalog
// ---------------------------------------------------------------------------

class _DemoUser {
  final String id;
  final String name;
  final String emoji;
  const _DemoUser(this.id, this.name, this.emoji);
}

const _allUsers = [
  _DemoUser('11111111-1111-1111-1111-111111111111', 'Alice', '👩‍💻'),
  _DemoUser('22222222-2222-2222-2222-222222222222', 'Bob', '👨‍💼'),
  _DemoUser('33333333-3333-3333-3333-333333333333', 'Charlie', '🧑‍🔬'),
];

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String get _currentId => ChatMessage.currentUserId;

  String get _currentName =>
      _allUsers.firstWhere((u) => u.id == _currentId,
          orElse: () => const _DemoUser('', 'Unknown', '?')).name;

  String get _currentEmoji =>
      _allUsers.firstWhere((u) => u.id == _currentId,
          orElse: () => const _DemoUser('', 'Unknown', '?')).emoji;

  Future<void> _initializeDemoData() async {
    try {
      final dio = sl<Dio>();
      await dio.post('/api/v1/simulation/initialize');
    } catch (e) {
      debugPrint('Demo data initialization error: $e');
    }
  }

  Future<void> _changeUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    await prefs.remove('current_user_name');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Contacts = everyone except me
    final contacts =
        _allUsers.where((u) => u.id != _currentId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Initialize Demo Data',
            onPressed: () async {
              await _initializeDemoData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demo data initialized!')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.switch_account),
            tooltip: 'Change User',
            onPressed: _changeUser,
          ),
        ],
      ),
      body: Column(
        children: [
          // Current user banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.blue[50],
            child: Row(
              children: [
                Text(_currentEmoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logged in as $_currentName',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    Text(
                      _currentId,
                      style: TextStyle(fontSize: 11, color: Colors.blue[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chat list
          Expanded(
            child: ListView(
              children: [
                // Direct messages
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'DIRECT MESSAGES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ...contacts.map((user) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        user.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    title: Text(user.name),
                    subtitle: const Text('Tap to chat'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            userId: user.id,
                            chatName: user.name,
                          ),
                        ),
                      );
                    },
                  );
                }),

                // Group chat
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'GROUP CHATS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange[100],
                    child: const Text('👥', style: TextStyle(fontSize: 24)),
                  ),
                  title: const Text('Development Team'),
                  subtitle: const Text('Team chat for developers'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatScreen(
                          groupId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                          chatName: 'Development Team',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
