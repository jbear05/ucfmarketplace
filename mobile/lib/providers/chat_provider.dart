import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/thread.dart';
import '../models/message.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final _api = ApiService();
  IO.Socket? _socket;

  List<Thread>              _threads        = [];
  Map<String, List<Message>> _messages      = {};
  final Map<String, bool>   _hasRated       = {};
  int                        _unread        = 0;
  bool                       _isLoading     = false;
  String?                    _activeThreadId;

  List<Thread> get threads   => _threads;
  int          get unread    => _unread;
  bool         get isLoading => _isLoading;

  List<Message> messagesFor(String threadId) => _messages[threadId] ?? [];
  bool hasRated(String threadId) => _hasRated[threadId] ?? false;

  Future<void> fetchThreads() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get('/threads');
      final data = res.data['data'];
      _threads = (data['threads'] as List).map((e) => Thread.fromJson(e)).toList();
      _unread  = data['totalUnread'] ?? 0;
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchUnreadCount() async {
    try {
      final res = await _api.get('/threads/unread-count');
      _unread = res.data['data']['unreadCount'] ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> openThread(String threadId) async {
    try {
      final res = await _api.get('/threads/$threadId/messages');
      _messages[threadId] = (res.data['data']['messages'] as List)
          .map((e) => Message.fromJson(e))
          .toList();
      _hasRated[threadId] = res.data['data']['hasRated'] ?? false;
      // Clear unread for this thread
      final idx = _threads.indexWhere((t) => t.id == threadId);
      if (idx != -1) {
        _unread = (_unread - _threads[idx].unreadCount).clamp(0, 9999);
        _threads[idx] = _threads[idx].copyWith(unreadCount: 0);
      }
      notifyListeners();
      _socket?.emit('joinThread', threadId);
    } catch (_) {}
  }

  void setActiveThread(String? threadId) {
    _activeThreadId = threadId;
  }

  void closeThread(String threadId) {
    _activeThreadId = null;
    _socket?.emit('leaveThread', threadId);
  }

  Future<Message?> sendMessage(String threadId, String body) async {
    try {
      final res = await _api.post('/threads/$threadId/messages', data: {'body': body});
      final msg = Message.fromJson(res.data['data']['message']);
      _messages[threadId] = [...messagesFor(threadId), msg];
      notifyListeners();
      return msg;
    } catch (_) {
      return null;
    }
  }

  Future<Thread?> createThread(String listingId, {String message = 'Hi, I am interested in your listing!'}) async {
    try {
      final res = await _api.post('/threads', data: {'listingId': listingId, 'message': message});
      final thread = Thread.fromJson(res.data['data']['thread']);
      _threads.insert(0, thread);
      notifyListeners();
      return thread;
    } catch (e) {
      return null;
    }
  }

  /// Starts (or reuses) a support conversation with an admin and sends the
  /// given message. Returns the thread id on success, or an error message.
  Future<({String? threadId, String? error})> contactAdmin(String message) async {
    try {
      final res = await _api.post('/threads/contact-admin', data: {'message': message});
      final thread = Thread.fromJson(res.data['data']['thread']);
      final idx = _threads.indexWhere((t) => t.id == thread.id);
      if (idx != -1) {
        _threads[idx] = thread;
      } else {
        _threads.insert(0, thread);
      }
      notifyListeners();
      return (threadId: thread.id, error: null);
    } on DioException catch (e) {
      final String errorMsg = e.response?.data?['message'] ?? 'Failed to send message';
      return (threadId: null, error: errorMsg);
    }
  }

  Future<String?> proposeMeetup(String threadId, {
    required String address,
    required double lat,
    required double lng,
    DateTime? scheduledAt,
  }) async {
    try {
      final res = await _api.patch('/threads/$threadId/meetup', data: {
        'address': address,
        'lat': lat,
        'lng': lng,
        if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
      });
      final thread = Thread.fromJson(res.data['data']['thread']);
      final idx = _threads.indexWhere((t) => t.id == threadId);
      if (idx != -1) _threads[idx] = thread;
      // Refresh messages so the system message shows up
      await openThread(threadId);
      notifyListeners();
      return null;
    } on Exception catch (_) {
      return 'Failed to propose meetup';
    }
  }

  Future<String?> respondMeetup(String threadId, String action) async {
    try {
      final res = await _api.patch('/threads/$threadId/meetup/respond', data: {'action': action});
      final thread = Thread.fromJson(res.data['data']['thread']);
      final idx = _threads.indexWhere((t) => t.id == threadId);
      if (idx != -1) _threads[idx] = thread;
      notifyListeners();
      return null;
    } catch (_) {
      return 'Failed to update meetup';
    }
  }

  Future<String?> completeMeetup(String threadId) async {
    try {
      final res = await _api.patch('/threads/$threadId/meetup/complete');
      final thread = Thread.fromJson(res.data['data']['thread']);
      final idx = _threads.indexWhere((t) => t.id == threadId);
      if (idx != -1) _threads[idx] = thread;
      notifyListeners();
      return null;
    } catch (_) {
      return 'Failed to complete meetup';
    }
  }

  Future<String?> rateThread(String threadId, {required int score, String? feedback}) async {
    try {
      await _api.post('/threads/$threadId/rate', data: {
        'score': score,
        if (feedback != null && feedback.trim().isNotEmpty) 'feedback': feedback.trim(),
      });
      _hasRated[threadId] = true;
      notifyListeners();
      return null;
    } on DioException catch (e) {
      return e.response?.data?['message'] ?? 'Failed to submit rating';
    }
  }

  Future<void> blockThread(String threadId) async {
    try {
      await _api.patch('/threads/$threadId/block');
      final idx = _threads.indexWhere((t) => t.id == threadId);
      if (idx != -1) {
        _threads[idx] = _threads[idx].copyWith(isBlocked: !_threads[idx].isBlocked);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> deleteThread(String threadId) async {
    try {
      await _api.patch('/threads/$threadId/delete');
      _threads.removeWhere((t) => t.id == threadId);
      _messages.remove(threadId);
      notifyListeners();
    } catch (_) {}
  }

  String? _connectedUserId;

  void initSocketListeners({String? userId}) {
    // Already connected as this exact user — nothing to do.
    if (_socket != null && _connectedUserId == userId) return;
    // Connected as a DIFFERENT user (e.g. switched accounts without
    // restarting the app) — tear down the stale connection first, or it
    // keeps delivering events from the old account's rooms forever.
    if (_socket != null) disconnectSocket();

    _connectedUserId = userId;
    const baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://192.168.86.243:5000');
    _socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'auth': {'userId': userId},
    });
    _socket!.on('newMessage', (data) {
      final threadId = data['threadId'] as String;
      final msg      = Message.fromJson(data['message']);
      _messages[threadId] = [...messagesFor(threadId), msg];
      final idx = _threads.indexWhere((t) => t.id == threadId);
      if (idx != -1) {
        _threads[idx] = _threads[idx].copyWith(
          lastMessage:   msg.body,
          lastMessageAt: msg.createdAt,
        );
      }
      // Only increment unread if user is not currently reading this thread
      if (_activeThreadId != threadId) {
        _unread++;
      }
      notifyListeners();
    });
    _socket!.on('meetupUpdate', (data) {
      final threadId = data['threadId'] as String;
      final idx = _threads.indexWhere((t) => t.id == threadId);
      if (idx != -1) {
        _threads[idx] = _threads[idx].copyWith(meetup: ThreadMeetup.fromJson(data['meetup']));
        notifyListeners();
      }
    });
  }

  void disconnectSocket() {
    _socket?.disconnect();
    _socket = null;
    _connectedUserId = null;
    // Clear cached chat state — it belongs to whichever account was
    // connected before, and must not leak into the next login.
    _threads = [];
    _messages = {};
    _hasRated.clear();
    _unread = 0;
    _activeThreadId = null;
    notifyListeners();
  }
}
