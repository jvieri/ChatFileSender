import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/chat_message.dart';

class UserSelectionScreen extends StatelessWidget {
  const UserSelectionScreen({super.key});

  static const _users = [
    {
      'id': '11111111-1111-1111-1111-111111111111',
      'name': 'Alice',
      'emoji': '👩‍💻',
    },
    {
      'id': '22222222-2222-2222-2222-222222222222',
      'name': 'Bob',
      'emoji': '👨‍💼',
    },
    {
      'id': '33333333-3333-3333-3333-333333333333',
      'name': 'Charlie',
      'emoji': '🧑‍🔬',
    },
  ];

  Future<void> _selectUser(
    BuildContext context,
    String id,
    String name,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_id', id);
    await prefs.setString('current_user_name', name);
    ChatMessage.currentUserId = id;

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_circle, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                const Text(
                  'Who are you?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select your identity for this demo session',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ..._users.map((user) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () =>
                            _selectUser(context, user['id']!, user['name']!),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user['emoji']!,
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              user['name']!,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
