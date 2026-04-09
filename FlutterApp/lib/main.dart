import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'di/injection.dart';
import 'presentation/bloc/chat_bloc.dart';
import 'presentation/bloc/file_upload_bloc.dart';
import 'presentation/screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependencies
  await initDependencies();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ChatBloc>(
          create: (_) => sl<ChatBloc>(),
        ),
        BlocProvider<FileUploadBloc>(
          create: (_) => sl<FileUploadBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'Chat with Files',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  
  Future<void> _initializeDemoData() async {
    try {
      final dio = sl<Dio>();
      await dio.post('/api/v1/simulation/initialize');
    } catch (e) {
      print('Demo data initialization error: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
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
        ],
      ),
      body: Column(
        children: [
          // Demo info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Demo Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a chat below to start messaging. '
                  'Use the simulator panel to send test messages.',
                  style: TextStyle(color: Colors.blue[900]),
                ),
              ],
            ),
          ),
          
          // Chat list
          Expanded(
            child: ListView(
              children: [
                // Direct chats section
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
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple[100],
                    child: Text('👩‍💻', style: const TextStyle(fontSize: 24)),
                  ),
                  title: const Text('Alice'),
                  subtitle: const Text('Click to chat'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatScreen(
                          userId: '11111111-1111-1111-1111-111111111111',
                          chatName: 'Alice',
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text('👨‍💼', style: const TextStyle(fontSize: 24)),
                  ),
                  title: const Text('Bob'),
                  subtitle: const Text('Click to chat'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatScreen(
                          userId: '22222222-2222-2222-2222-222222222222',
                          chatName: 'Bob',
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Text('🧑‍🔬', style: const TextStyle(fontSize: 24)),
                  ),
                  title: const Text('Charlie'),
                  subtitle: const Text('Click to chat'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatScreen(
                          userId: '33333333-3333-3333-3333-333333333333',
                          chatName: 'Charlie',
                        ),
                      ),
                    );
                  },
                ),
                
                // Group chats section
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
                    child: Text('👥', style: const TextStyle(fontSize: 24)),
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
