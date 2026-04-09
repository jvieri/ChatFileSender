import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/chat_message.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/file_upload_bloc.dart';
import '../widgets/file_attachment_widget.dart';
import '../widgets/message_bubble_widget.dart';

class ChatScreen extends StatefulWidget {
  final String? userId;
  final String? groupId;
  final String chatName;
  
  const ChatScreen({
    super.key,
    this.userId,
    this.groupId,
    required this.chatName,
  });
  
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isShowSimulator = false;
  
  String get chatId => widget.groupId ?? widget.userId ?? '';
  
  @override
  void initState() {
    super.initState();
    
    // Set current user ID (in real app, this comes from auth)
    ChatMessage.currentUserId = 'current-user-id';
    
    context.read<ChatBloc>().add(JoinChatEvent(chatId));
    context.read<ChatBloc>().add(
      LoadMessagesEvent(userId: widget.userId, groupId: widget.groupId),
    );
  }
  
  @override
  void dispose() {
    context.read<ChatBloc>().add(LeaveChatEvent(chatId));
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    context.read<ChatBloc>().add(SendMessageEvent(text));
    _messageController.clear();
    
    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  void _attachFile() {
    context.read<FileUploadBloc>().add(SelectFileEvent());
  }
  
  void _simulateMessage(String senderId, String senderName, String text) {
    context.read<ChatBloc>().add(
      SimulateReceiveMessageEvent(
        senderId: senderId,
        senderName: senderName,
        textContent: text,
      ),
    );
    
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chatName),
            BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.isConnected ? Icons.wifi : Icons.wifi_off,
                      color: state.isConnected ? Colors.green : Colors.red,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      state.isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        fontSize: 11,
                        color: state.isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isShowSimulator ? Icons.toggle_on : Icons.toggle_off,
              color: _isShowSimulator ? Colors.green : null,
            ),
            tooltip: 'Toggle Simulator',
            onPressed: () {
              setState(() {
                _isShowSimulator = !_isShowSimulator;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, chatState) {
                if (chatState.isLoading && chatState.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (chatState.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send the first message!',
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }
                
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels == 0 && 
                        notification is ScrollEndNotification) {
                      // User scrolled to top, load more
                      context.read<ChatBloc>().add(LoadMoreMessagesEvent());
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: false,
                    padding: const EdgeInsets.all(8),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      return MessageBubbleWidget(message: message);
                    },
                  ),
                );
              },
            ),
          ),
          
          // File upload progress bar
          BlocBuilder<FileUploadBloc, FileUploadState>(
            builder: (context, uploadState) {
              if (uploadState.activeUploads.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.blue[50],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: uploadState.activeUploads.map((file) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              value: file.uploadProgress / 100,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              file.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '${file.uploadProgress}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          
          // Simulator Panel
          if (_isShowSimulator) _buildSimulatorPanel(),
          
          // Input area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey[300]!,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _attachFile,
                  tooltip: 'Attach file',
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                BlocBuilder<FileUploadBloc, FileUploadState>(
                  builder: (context, uploadState) {
                    final hasFiles = uploadState.selectedFiles.isNotEmpty;
                    
                    return FloatingActionButton.small(
                      onPressed: hasFiles ? null : _sendMessage,
                      child: Icon(hasFiles ? Icons.file_upload : Icons.send),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      
      // Selected files bottom sheet
      bottomSheet: BlocBuilder<FileUploadBloc, FileUploadState>(
        builder: (context, state) {
          if (state.selectedFiles.isEmpty) return const SizedBox.shrink();
          
          return Container(
            height: 120,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.selectedFiles.length} file(s) selected',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.selectedFiles.length,
                    itemBuilder: (context, index) {
                      final file = state.selectedFiles[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            FileAttachmentWidget(attachment: file),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  context
                                      .read<FileUploadBloc>()
                                      .add(RemoveFileEvent(file.id));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSimulatorPanel() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.science, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Chat Simulator',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    // Simulate multiple messages
                    _simulateMessage(
                      'user-1',
                      'Alice',
                      'Hey! How are you doing? 👋',
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Quick Test'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSimulatorUser(
                    'Alice',
                    '👩‍💻',
                    'user-1',
                    [
                      'Hey! How are you doing? 👋',
                      'Did you see the new update?',
                      'Let me check that for you',
                      'Great work! 🎉',
                      'I\'ll send you the files shortly',
                    ],
                  ),
                  _buildSimulatorUser(
                    'Bob',
                    '👨‍💼',
                    'user-2',
                    [
                      'Hi there!',
                      'Can you review my PR?',
                      'Meeting at 3pm today',
                      'Thanks for the help!',
                      'Sounds good to me 👍',
                    ],
                  ),
                  _buildSimulatorUser(
                    'Charlie',
                    '🧑‍🔬',
                    'user-3',
                    [
                      'Hello team!',
                      'I found a bug in the system',
                      'Working on a fix now',
                      'Deployed to staging ✅',
                      'Tests are passing',
                    ],
                  ),
                  _buildSimulatorUser(
                    'Diana',
                    '👩‍🎨',
                    'user-4',
                    [
                      'New designs are ready!',
                      'Check out the mockups',
                      'What do you think about this color?',
                      'I\'ll update the Figma file',
                      'Looks perfect! 🎨',
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSimulatorUser(
    String name,
    String emoji,
    String userId,
    List<String> quickMessages,
  ) {
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              const Text(
                'Quick Messages:',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              ...quickMessages.map((msg) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _simulateMessage(userId, name, msg),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        msg,
                        style: const TextStyle(fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
