part of 'chat_bloc.dart';

class ChatState extends Equatable {
  final bool isLoading;
  final bool isConnected;
  final bool hasMore;
  final int currentPage;
  final String? chatId;
  final String? userId;
  final String? groupId;
  final String? errorMessage;
  final List<ChatMessage> messages;
  
  const ChatState({
    this.isLoading = false,
    this.isConnected = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.chatId,
    this.userId,
    this.groupId,
    this.errorMessage,
    this.messages = const [],
  });
  
  ChatState copyWith({
    bool? isLoading,
    bool? isConnected,
    bool? hasMore,
    int? currentPage,
    String? chatId,
    String? userId,
    String? groupId,
    String? errorMessage,
    List<ChatMessage>? messages,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      chatId: chatId ?? this.chatId,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      errorMessage: errorMessage,
      messages: messages ?? this.messages,
    );
  }
  
  @override
  List<Object?> get props => [
        isLoading,
        isConnected,
        hasMore,
        currentPage,
        chatId,
        userId,
        groupId,
        errorMessage,
        messages,
      ];
}
