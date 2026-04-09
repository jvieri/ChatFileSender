import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';

class SignalRService {
  HubConnection? _hubConnection;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _fileProgressController = StreamController<Map<String, dynamic>>.broadcast();
  final _fileCompletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _fileErrorController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get fileProgressStream => _fileProgressController.stream;
  Stream<Map<String, dynamic>> get fileCompletedStream => _fileCompletedController.stream;
  Stream<Map<String, dynamic>> get fileErrorStream => _fileErrorController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  
  bool get isConnected => _hubConnection?.state == HubConnectionState.Connected;
  
  Future<void> connect(String serverUrl, String accessToken) async {
    if (_hubConnection != null && isConnected) {
      await disconnect();
    }
    
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          serverUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => accessToken,
          ),
        )
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 20000])
        .build();
    
    // Set up event handlers
    _hubConnection!.on('ReceiveMessage', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        _messageController.add(arguments.first as Map<String, dynamic>);
      }
    });
    
    _hubConnection!.on('FileUploadProgress', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        _fileProgressController.add(arguments.first as Map<String, dynamic>);
      }
    });
    
    _hubConnection!.on('FileProcessingCompleted', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        _fileCompletedController.add(arguments.first as Map<String, dynamic>);
      }
    });
    
    _hubConnection!.on('FileError', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        _fileErrorController.add(arguments.first as Map<String, dynamic>);
      }
    });
    
    _hubConnection!.on('TypingIndicator', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        _typingController.add(arguments.first as Map<String, dynamic>);
      }
    });
    
    // Reconnection handler
    _hubConnection!.onreconnecting(({error}) {
      print('SignalR reconnecting: $error');
    });
    
    _hubConnection!.onreconnected(({connectionId}) {
      print('SignalR reconnected: $connectionId');
    });
    
    _hubConnection!.onclose(({error}) {
      print('SignalR connection closed: $error');
    });
    
    await _hubConnection!.start();
  }
  
  Future<void> joinChat(String chatId) async {
    await _hubConnection?.invoke('JoinChat', args: [chatId]);
  }
  
  Future<void> leaveChat(String chatId) async {
    await _hubConnection?.invoke('LeaveChat', args: [chatId]);
  }
  
  Future<void> reportUploadProgress(String fileId, int progress, String status) async {
    await _hubConnection?.invoke(
      'ReportUploadProgress',
      args: [fileId, progress, status],
    );
  }
  
  Future<void> sendTypingIndicator(String chatId, bool isTyping) async {
    await _hubConnection?.invoke(
      'SendTypingIndicator',
      args: [chatId, isTyping],
    );
  }
  
  Future<void> disconnect() async {
    await _hubConnection?.stop();
    _hubConnection = null;
  }
  
  void dispose() {
    _messageController.close();
    _fileProgressController.close();
    _fileCompletedController.close();
    _fileErrorController.close();
    _typingController.close();
    disconnect();
  }
}
