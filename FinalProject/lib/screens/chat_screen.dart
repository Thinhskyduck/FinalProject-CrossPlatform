// --- START OF FILE chat_screen.dart (CUSTOMER APP) ---
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart'
    as status; // Dùng cho mã đóng rõ ràng

void _logPrint(String screen, String message) {
  if (kDebugMode) {
    print("[$screen] $message");
  }
}

enum TypeMessage { text }

class ChatScreen extends StatefulWidget {
  final String role = "customer";

  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final String _screenName = "ChatScreen";

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final String _websocketBaseUrl =
      "wss://s7et8q6051.execute-api.ap-southeast-1.amazonaws.com/dev/";
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _manuallyDisconnecting = false;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 7;
  final Duration _initialReconnectDelay = const Duration(seconds: 2);
  final Duration _maxReconnectDelay = const Duration(seconds: 60);

  Timer? _connectionInitializationTimeout;
  // TĂNG THỜI GIAN TIMEOUT
  final Duration _connectionInitializationTimeoutDuration =
      const Duration(seconds: 15);

  String? _currentUserId;
  static const int ADMIN_FASTAPI_USER_ID = 1;

  bool _isInitializingApp = true;
  String? _errorMessage;
  bool _isLoadingHistory = false;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _logPrint(_screenName, "initState called");
    _focusNode.addListener(_onFocusChange);
    _loadUserIdAndConnect();
  }

  @override
  void dispose() {
    _logPrint(_screenName, "dispose called");
    _manuallyDisconnecting = true;
    _reconnectTimer?.cancel();
    _connectionInitializationTimeout?.cancel();
    _closeExistingChannel(isDisposing: true, customCloseCode: status.goingAway);

    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserIdAndConnect() async {
    _logPrint(_screenName, "Loading user ID and connecting...");
    if (!mounted) return;
    setState(() {
      _isInitializingApp = true;
      _errorMessage = null;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final userIdString = prefs.getString('user_uid');
      _logPrint(
          _screenName, "Backend User ID from SharedPreferences: $userIdString");

      if (userIdString == null || userIdString.isEmpty) {
        throw Exception(
            "Backend User ID không tìm thấy. Vui lòng đăng nhập lại.");
      }
      _currentUserId = userIdString;

      if (mounted) {
        await _fetchChatHistory();
        await _establishWebSocketConnection(isRetry: false); // Gọi kết nối WS
      }
    } catch (e) {
      _logPrint(_screenName, "Error loading user ID: $e");
      if (mounted) {
        setState(() {
          _isInitializingApp = false;
          _errorMessage =
              "Không thể tải thông tin người dùng: ${e.toString().replaceFirst('Exception: ', '')}";
        });
      }
    }
    // Không cần finally ở đây nữa, _isInitializingApp sẽ được quản lý bởi các hàm con
  }

  Future<void> _fetchChatHistory() async {
    // ... (Giữ nguyên hàm _fetchChatHistory như phiên bản bạn đã cung cấp,
    //      chỉ cần đảm bảo nó cập nhật _isInitializingApp = false trong finally nếu nó là bước cuối)
    //      Ví dụ:
    //      finally {
    //        if (mounted) {
    //          setState(() {
    //            _isLoadingHistory = false;
    //            if (_isInitializingApp && !_isConnecting && !_isConnected) {
    //               // Nếu đây là bước cuối của init và WS chưa kết nối, thì kết thúc init
    //               _isInitializingApp = false;
    //            }
    //          });
    //        }
    //      }
    // Hoặc đơn giản hơn, để _establishWebSocketConnection xử lý _isInitializingApp
    // --- BẮT ĐẦU _fetchChatHistory ---
    if (_currentUserId == null) {
      _logPrint(_screenName, "Cannot fetch history, _currentUserId is null.");
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          if (_isInitializingApp) _isInitializingApp = false;
        });
      }
      return;
    }
    if (!mounted) return;
    _logPrint(_screenName, "Fetching chat history for user $_currentUserId...");
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final historyUrl = Uri.parse(
        'https://tteaqwe3g9.ap-southeast-1.awsapprunner.com/api/v1/support/history',
      );
      final response = await http.get(
        historyUrl,
        headers: {
          'accept': 'application/json',
          'X-User-ID': _currentUserId!,
        },
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> historyData =
            jsonDecode(utf8.decode(response.bodyBytes));
        final List<Map<String, dynamic>> formattedHistory =
            historyData.map((msg) {
          return {
            'senderId': msg['sender_id'],
            'recipientId': msg['receiver_id'],
            'content': msg['message_content'],
            'type': TypeMessage.text.index,
            'timestamp': DateTime.parse(msg['sent_at']).millisecondsSinceEpoch,
            'read': msg['is_read'] ?? false,
            'attachmentUrl': msg['attachment_url'] ?? '',
          };
        }).toList();

        setState(() {
          _messages = formattedHistory;
          _errorMessage = null;
          _logPrint(_screenName,
              "Fetched ${_messages.length} messages from history.");
        });
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom(immediate: true));
      } else {
        final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
        final detail = errorBody['detail'] ?? 'Lỗi không xác định';
        throw Exception(
            'Không thể tải lịch sử chat: $detail (${response.statusCode})');
      }
    } catch (e) {
      _logPrint(_screenName, 'Error fetching chat history: $e');
      if (mounted) {
        setState(() {
          _errorMessage =
              "Lỗi tải lịch sử: ${e.toString().replaceFirst('Exception: ', '')}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          // Nếu không có WS đang kết nối, và app vẫn đang init, thì kết thúc init ở đây
          if (_isInitializingApp &&
              !_isConnecting &&
              !_isConnected &&
              _channel == null) {
            _isInitializingApp = false;
          }
        });
      }
    }
    // --- KẾT THÚC _fetchChatHistory ---
  }

  Future<void> _establishWebSocketConnection({required bool isRetry}) async {
    if (_manuallyDisconnecting) {
      _logPrint(
          _screenName, "WebSocket connection aborted: manual disconnect.");
      if (mounted) setState(() => _isConnecting = false);
      return;
    }
    if (_currentUserId == null) {
      _logPrint(
          _screenName, "WebSocket connection aborted: _currentUserId is null.");
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = "Thiếu thông tin người dùng để kết nối chat.";
          if (_isInitializingApp) _isInitializingApp = false;
        });
      }
      return;
    }
    if (_isConnecting && !isRetry) {
      _logPrint(
          _screenName, "WebSocket connection attempt already in progress.");
      return;
    }
    if (_isConnected && !isRetry) {
      _logPrint(_screenName, "Already connected to WebSocket.");
      if (mounted && _isInitializingApp) {
        setState(() => _isInitializingApp = false);
      }
      return;
    }

    await _closeExistingChannel();

    _logPrint(_screenName,
        "Attempting to connect WebSocket for user $_currentUserId (role: ${widget.role})...");
    if (mounted) {
      setState(() {
        _isConnecting = true;
        if (!isRetry && _errorMessage?.startsWith("Mất kết nối") == false) {
          _errorMessage = null;
        }
      });
    }

    try {
      final wsUrl = Uri.parse(
        '$_websocketBaseUrl?userId=$_currentUserId&role=${widget.role}',
      );
      _logPrint(_screenName, "Connecting to WebSocket URL: $wsUrl");
      _channel = WebSocketChannel.connect(wsUrl);
      _logPrint(_screenName,
          "WebSocket channel initialized. Setting up listener and timeout.");

      _connectionInitializationTimeout?.cancel();
      _connectionInitializationTimeout =
          Timer(_connectionInitializationTimeoutDuration, () {
        if (mounted && _isConnecting && !_isConnected) {
          _logPrint(_screenName,
              "Connection initialization timeout! WebSocket didn't confirm in time.");
          _handleConnectionLost(reason: "Initialization Timeout");
        }
      });

      _listenToChannelStream();
    } catch (e) {
      _logPrint(_screenName, "Error during WebSocketChannel.connect: $e");
      _handleConnectionLost(
          reason: "Exception in WebSocketChannel.connect: $e");
    } finally {
      // Cuối cùng, nếu app vẫn đang init và không có kết nối nào đang diễn ra
      // thì đánh dấu init hoàn tất.
      if (mounted && _isInitializingApp && !_isConnecting && !_isConnected) {
        setState(() => _isInitializingApp = false);
      }
    }
  }

  void _listenToChannelStream() {
    _streamSubscription?.cancel();
    _streamSubscription = _channel?.stream.listen(
      (data) {
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          _logPrint(_screenName, "Received WebSocket message: $message");

          if (message['type'] == 'connectionEstablished') {
            _logPrint(_screenName, "Connection confirmed by server.");
            if (mounted) {
              setState(() {
                _isConnected = true;
                _isConnecting = false;
                _errorMessage = null;
                if (_isInitializingApp) _isInitializingApp = false;
              });
              _reconnectAttempts = 0;
              _connectionInitializationTimeout?.cancel();
            }
            return;
          }

          if (!_isConnected) {
            _logPrint(_screenName, "Ignoring message: Not connected yet.");
            return;
          }

          if (message['type'] != 'newMessage') return;
          if (mounted) {
            setState(() {
              _messages.insert(0, {
                'senderId': int.parse(message['senderId'].toString()),
                'recipientId': int.parse(message['recipientId'].toString()),
                'content': message['content'] as String,
                'type': _mapTypeToIndex(message['type'] as String?),
                'timestamp': message['timestamp'] as int,
                'read': false,
                'attachmentUrl': message['attachmentUrl']?.toString() ?? '',
              });
            });
            _scrollToBottom();
          }
        } catch (e) {
          _logPrint(_screenName, 'Error decoding message: $e. Data: $data');
        }
      },
      onDone: () {
        _logPrint(_screenName,
            "WebSocket channel closed. Code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}");
        if (mounted)
          _handleConnectionLost(
              reason: "onDone - Channel closed (Code: ${_channel?.closeCode})");
      },
      onError: (error) {
        _logPrint(_screenName, "WebSocket stream error: $error");
        if (mounted)
          _handleConnectionLost(reason: "onError - Stream error: $error");
      },
      cancelOnError: true,
    );
    _logPrint(_screenName, "Stream listener attached.");

    if (_isConnecting && !_isConnected) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted &&
            _isConnecting &&
            !_isConnected &&
            _channel != null &&
            _streamSubscription != null &&
            !_manuallyDisconnecting) {
          _logPrint(_screenName,
              "Optimistically setting connected status after 500ms.");
          setState(() {
            _isConnected = true;
            _isConnecting = false;
            _errorMessage = null;
            if (_isInitializingApp) _isInitializingApp = false;
          });
          _reconnectAttempts = 0;
          _connectionInitializationTimeout?.cancel();
        } else {
          _logPrint(_screenName,
              "Optimistic connection check after 500ms: Conditions NOT met. isConnecting: $_isConnecting, isConnected: $_isConnected, manuallyDisconnecting: $_manuallyDisconnecting");
        }
      });
    }
  }

  void _handleConnectionLost({String? reason}) {
    _logPrint(_screenName,
        "Handling connection lost. Reason: ${reason ?? 'Unknown'}. Manual disconnect: $_manuallyDisconnecting. Current state: isConnected=$_isConnected, isConnecting=$_isConnecting");
    _connectionInitializationTimeout?.cancel();

    bool stateActuallyChanged = false;
    if (_isConnected) {
      _isConnected = false;
      stateActuallyChanged = true;
    }
    if (_isConnecting) {
      _isConnecting = false;
      stateActuallyChanged = true;
    }

    if (mounted) {
      if (_errorMessage == null ||
          (reason != null &&
              !_errorMessage!
                  .contains(reason.substring(0, math.min(reason.length, 10))) &&
              !_manuallyDisconnecting)) {
        if (reason != null && !_manuallyDisconnecting) {
          _errorMessage = "Mất kết nối: $reason. Đang thử lại...";
          stateActuallyChanged = true;
        }
      }
      if (stateActuallyChanged) {
        setState(() {});
      }
      if (_isInitializingApp && !_isConnecting && !_isConnected) {
        // Nếu đang init mà mất kết nối hoàn toàn
        setState(() => _isInitializingApp = false);
      }
    }

    _streamSubscription?.cancel();
    _streamSubscription = null;
    // _channel = null; // Để _closeExistingChannel xử lý

    if (!_manuallyDisconnecting && _currentUserId != null) {
      _scheduleReconnect();
    } else {
      _logPrint(_screenName, "Not scheduling reconnect.");
    }
  }

  void _scheduleReconnect() {
    if (_manuallyDisconnecting) {
      _logPrint(
          _screenName, "Reconnect scheduling aborted: manual disconnect.");
      return;
    }
    if (_isConnecting) {
      _logPrint(_screenName,
          "Reconnect scheduling aborted: connection attempt already in progress.");
      return;
    }
    if (!mounted) {
      // Thêm kiểm tra mounted
      _logPrint(
          _screenName, "Reconnect scheduling aborted: widget not mounted.");
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logPrint(_screenName,
          "Max reconnect attempts ($_maxReconnectAttempts) reached. Giving up.");
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isConnected = false;
          _errorMessage =
              "Không thể kết nối lại sau nhiều lần thử. Vui lòng kiểm tra mạng và thử lại thủ công.";
        });
      }
      return;
    }

    _reconnectAttempts++;
    final delaySeconds = math
        .min(
            _maxReconnectDelay.inSeconds,
            _initialReconnectDelay.inSeconds *
                math.pow(2, _reconnectAttempts - 1))
        .toInt();
    final prochaineDelay = Duration(seconds: delaySeconds);

    _logPrint(_screenName,
        "Scheduling reconnect attempt #$_reconnectAttempts in ${prochaineDelay.inSeconds} seconds...");

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(prochaineDelay, () {
      if (mounted &&
          !_isConnected &&
          !_manuallyDisconnecting &&
          _currentUserId != null &&
          !_isConnecting) {
        _logPrint(_screenName, "Attempting reconnect #$_reconnectAttempts...");
        // setState(() => _isConnecting = true); // _establishWebSocketConnection sẽ set
        _establishWebSocketConnection(isRetry: true);
      } else {
        _logPrint(_screenName,
            "Reconnect attempt #$_reconnectAttempts aborted: conditions not met.");
      }
    });
  }

  Future<void> _closeExistingChannel(
      {bool isDisposing = false, int? customCloseCode}) async {
    if (_channel != null) {
      _logPrint(_screenName,
          "Closing existing WebSocket channel... isDisposing: $isDisposing, customCloseCode: $customCloseCode");
      if (!isDisposing) _connectionInitializationTimeout?.cancel();

      await _streamSubscription?.cancel();
      _streamSubscription = null;
      _logPrint(_screenName, "Stream subscription cancelled.");

      try {
        _logPrint(_screenName,
            "Attempting to close WebSocket sink with code: ${customCloseCode ?? 'default'}");
        await _channel!.sink.close(customCloseCode);
        _logPrint(_screenName, "WebSocket sink closed.");
      } catch (e) {
        _logPrint(_screenName, "Error closing sink for existing channel: $e");
      }
      _channel = null;
      _logPrint(_screenName,
          "Existing WebSocket channel resources released (channel set to null).");
    } else {
      _logPrint(_screenName, "No existing channel to close.");
    }
  }

  Future<void> _sendMessage(
    String content, [
    TypeMessage type = TypeMessage.text,
  ]) async {
    // ... (Giữ nguyên hàm _sendMessage như phiên bản bạn đã cung cấp,
    //      chỉ cần đảm bảo nó gọi _establishWebSocketConnection(isRetry: true) nếu cần)
    // --- BẮT ĐẦU _sendMessage ---
    if (_currentUserId == null) {
      _logPrint(_screenName, "Cannot send message: _currentUserId is null.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi: Thiếu thông tin người dùng.')),
      );
      return;
    }
    if (!_isConnected || _channel == null) {
      _logPrint(_screenName,
          "Cannot send message: Not connected or channel is null. isConnected: $_isConnected");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Không thể gửi tin nhắn. Đang thử kết nối lại...')),
      );
      if (!_isConnecting && !_manuallyDisconnecting && mounted) {
        // Thêm mounted check
        _logPrint(_screenName, "Triggering reconnect from sendMessage.");
        _establishWebSocketConnection(isRetry: true);
      }
      return;
    }

    if (content.trim().isEmpty) return;

    try {
      final message = {
        'action': 'sendMessage',
        'recipientId': ADMIN_FASTAPI_USER_ID.toString(),
        'content': content,
      };
      _logPrint(
          _screenName, "Sending WebSocket message: ${jsonEncode(message)}");
      _channel!.sink.add(jsonEncode(message));

      if (mounted) {
        setState(() {
          _messages.insert(0, {
            'senderId': int.parse(_currentUserId!),
            'recipientId': ADMIN_FASTAPI_USER_ID,
            'content': content,
            'type': type.index,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'read': true,
            'attachmentUrl': '',
          });
          _messageController.clear();
        });
        _scrollToBottom();
      }
    } catch (e) {
      _logPrint(_screenName, 'Error sending message via WebSocket: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi tin nhắn: $e')),
        );
        _handleConnectionLost(reason: "Error on sink.add: $e");
      }
    }
    // --- KẾT THÚC _sendMessage ---
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    // ... (Giữ nguyên hàm _scrollToBottom như phiên bản bạn đã cung cấp)
    // --- BẮT ĐẦU _scrollToBottom ---
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          if (immediate) {
            _scrollController
                .jumpTo(_scrollController.position.minScrollExtent);
          } else {
            _scrollController.animateTo(
              _scrollController.position.minScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
      });
    } else if (_scrollController.hasClients && immediate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        }
      });
    }
    // --- KẾT THÚC _scrollToBottom ---
  }

  int _mapTypeToIndex(String? type) {
    // ... (Giữ nguyên hàm _mapTypeToIndex như phiên bản bạn đã cung cấp)
    // --- BẮT ĐẦU _mapTypeToIndex ---
    if (type == 'newMessage' || type == 'text') return TypeMessage.text.index;
    return TypeMessage.text.index;
    // --- KẾT THÚC _mapTypeToIndex ---
  }

  Widget _buildAvatar(int userId) {
    // ... (Giữ nguyên hàm _buildAvatar như phiên bản bạn đã cung cấp)
    // --- BẮT ĐẦU _buildAvatar ---
    bool isCurrentUser = userId.toString() == _currentUserId;
    return CircleAvatar(
      radius: 16,
      backgroundColor: isCurrentUser ? Colors.blue[100] : Colors.grey[300],
      child: Icon(
        isCurrentUser ? Icons.person : Icons.support_agent,
        size: 20,
        color: isCurrentUser ? Colors.blue[700] : Colors.grey[700],
      ),
    );
    // --- KẾT THÚC _buildAvatar ---
  }

  Widget _buildMessageContent(Map<String, dynamic> data, TypeMessage type) {
    // ... (Giữ nguyên hàm _buildMessageContent như phiên bản bạn đã cung cấp)
    // --- BẮT ĐẦU _buildMessageContent ---
    return Text(
      data['content'],
      style: TextStyle(
        color: data['senderId'].toString() == _currentUserId
            ? Colors.white
            : Colors.black,
        fontSize: 16,
      ),
    );
    // --- KẾT THÚC _buildMessageContent ---
  }

  Widget _buildMessageItem(Map<String, dynamic> data) {
    // ... (Giữ nguyên hàm _buildMessageItem như phiên bản bạn đã cung cấp)
    // --- BẮT ĐẦU _buildMessageItem ---
    bool isCurrentUser = data['senderId'].toString() == _currentUserId;
    TypeMessage messageType = TypeMessage.values[data['type'] as int];
    DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
    bool isRead = data['read'] ?? false;
    String time = DateFormat('HH:mm').format(timestamp.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 1.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 12,
                    color: isRead ? Colors.blue : Colors.grey,
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisAlignment:
                isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isCurrentUser) ...[
                _buildAvatar(data['senderId']),
                const SizedBox(width: 8),
              ],
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isCurrentUser ? Colors.blue : Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _buildMessageContent(data, messageType),
              ),
              if (isCurrentUser) ...[
                const SizedBox(width: 8),
                _buildAvatar(data['senderId']),
              ],
            ],
          ),
        ],
      ),
    );
    // --- KẾT THÚC _buildMessageItem ---
  }

  Widget _buildErrorState(ThemeData theme, String message) {
    // ... (Giữ nguyên hàm _buildErrorState như phiên bản bạn đã cung cấp)
    // --- BẮT ĐẦU _buildErrorState ---
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: theme.colorScheme.error.withOpacity(0.8),
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              "Đã có lỗi xảy ra",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              onPressed: (_isConnecting || _isInitializingApp)
                  ? null
                  : _loadUserIdAndConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                textStyle: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
    // --- KẾT THÚC _buildErrorState ---
  }

  @override
  Widget build(BuildContext context) {
    // ... (Giữ nguyên hàm build như phiên bản bạn đã cung cấp, chỉ sửa điều kiện onPressed của nút refresh AppBar)
    // --- BẮT ĐẦU build ---
    final theme = Theme.of(context);

    Widget bodyContent;

    if (_isInitializingApp) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null &&
        _messages.isEmpty &&
        !_isLoadingHistory) {
      bodyContent = _buildErrorState(theme, _errorMessage!);
    } else {
      bodyContent = Column(
        children: [
          if (_isLoadingHistory && _messages.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_messages.isEmpty &&
              !_isLoadingHistory &&
              _errorMessage == null)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "Chưa có tin nhắn nào.\nBắt đầu cuộc trò chuyện với chúng tôi!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                reverse: true,
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, index) =>
                    _buildMessageItem(_messages[index]),
              ),
            ),
          if (_errorMessage != null &&
              (_messages.isNotEmpty || _isLoadingHistory))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700], fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Tải lại tin nhắn và kết nối",
            onPressed:
                (_isLoadingHistory || _isConnecting || _isInitializingApp)
                    ? null
                    : _loadUserIdAndConnect,
          )
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Column(
            children: [
              Expanded(child: bodyContent),
              Padding(
                padding: EdgeInsets.only(
                    // bottom: MediaQuery.of(context).viewInsets.bottom, // Có thể không cần nếu resizeToAvoidBottomInset hoạt động tốt
                    ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.send,
                            maxLines: null,
                            onTap: _scrollToBottom,
                            onSubmitted: (value) async {
                              if (value.trim().isNotEmpty) {
                                await _sendMessage(value);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Nhập tin nhắn...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: (_isConnecting || !_isConnected)
                              ? null
                              : () async {
                                  if (_messageController.text
                                      .trim()
                                      .isNotEmpty) {
                                    await _sendMessage(_messageController.text);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // --- KẾT THÚC build ---
  }
}
// --- END OF FILE chat_screen.dart (CUSTOMER APP) ---
