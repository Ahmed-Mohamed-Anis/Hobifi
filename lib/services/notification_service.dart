import 'package:flutter/foundation.dart';
import 'package:hobby_haven/models/notification_model.dart';
import 'package:hobby_haven/supabase/supabase_config.dart';

class NotificationService extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _disposed = false;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.read).length;

  Future<void> loadNotifications(String userId) async {
    if (_isLoading) return;
    _isLoading = true;
    _safeNotify();

    try {
      final rows = await SupabaseService.from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50) as List<dynamic>;

      _notifications = rows
          .map((r) => NotificationModel.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> markAllRead(String userId) async {
    final unread = _notifications.where((n) => !n.read).map((n) => n.id).toList();
    if (unread.isEmpty) return;

    try {
      await SupabaseService.from('notifications')
          .update({'read': true})
          .eq('user_id', userId)
          .eq('read', false);

      _notifications = _notifications
          .map((n) => n.read
              ? n
              : NotificationModel(
                  id: n.id,
                  userId: n.userId,
                  title: n.title,
                  body: n.body,
                  read: true,
                  createdAt: n.createdAt,
                ))
          .toList();
      _safeNotify();
    } catch (e) {
      debugPrint('Failed to mark notifications read: $e');
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
