import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

class SignalRService {
  HubConnection? _hubConnection;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _fileProgressController = StreamController<Map<String, dynamic>>.broadcast();
  final _fileCompletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _fileErrorController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get fileProgressStream => _fileProgressController.stream;
  Stream<Map<String, dynamic>> get fileCompletedStream => _fileCompletedController.stream;
  Stream<Map<String, dynamic>> get fileErrorStream => _fileErrorController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected => _hubConnection?.state == HubConnectionState.Connected;

  Future<void> connect(String serverUrl) async {
    if (_hubConnection != null && isConnected) {
      debugPrint('[SignalR] Already connected, skipping connect()');
      return;
    }

    debugPrint('[SignalR] Connecting to: $serverUrl');

    try {
      if (_hubConnection != null) {
        await disconnect();
      }

      _hubConnection = HubConnectionBuilder()
          .withUrl(serverUrl)
          .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 20000])
          .build();

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

      _hubConnection!.onreconnecting(({error}) {
        debugPrint('[SignalR] Reconnecting... error: $error');
        _connectionStateController.add(false);
      });

      _hubConnection!.onreconnected(({connectionId}) {
        debugPrint('[SignalR] Reconnected. connectionId: $connectionId');
        _connectionStateController.add(true);
      });

      _hubConnection!.onclose(({error}) {
        debugPrint('[SignalR] Connection closed. error: $error');
        _connectionStateController.add(false);
      });

      await _hubConnection!.start();
      debugPrint('[SignalR] Connected successfully. State: ${_hubConnection!.state}');
      _connectionStateController.add(true);
    } catch (e, stack) {
      debugPrint('[SignalR] Connection FAILED: $e');
      debugPrint('[SignalR] Stack: $stack');
      _connectionStateController.add(false);
      rethrow;
    }
  }

  Future<void> joinChat(String chatId) async {
    if (!isConnected) {
      debugPrint('[SignalR] joinChat("$chatId") skipped — not connected');
      return;
    }
    debugPrint('[SignalR] Joining chat: $chatId');
    await _hubConnection!.invoke('JoinChat', args: [chatId]);
  }

  Future<void> leaveChat(String chatId) async {
    if (!isConnected) return;
    await _hubConnection!.invoke('LeaveChat', args: [chatId]);
  }

  Future<void> reportUploadProgress(String fileId, int progress, String status) async {
    if (!isConnected) return;
    await _hubConnection!.invoke('ReportUploadProgress', args: [fileId, progress, status]);
  }

  Future<void> sendTypingIndicator(String chatId, bool isTyping) async {
    if (!isConnected) return;
    await _hubConnection!.invoke('SendTypingIndicator', args: [chatId, isTyping]);
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
    _connectionStateController.close();
    disconnect();
  }
}
