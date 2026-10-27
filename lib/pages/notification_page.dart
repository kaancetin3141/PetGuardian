import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petguardian/pages/messages/chat_list_page.dart';
import 'package:petguardian/pages/shop_page.dart';
import 'package:petguardian/pages/pet_detail_page.dart';
import 'package:petguardian/stuff/formatters.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String? _currentUserUID;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserUID = user.uid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserUID == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Bildirimler'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Bildirimler'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              'Tümünü Okundu İşaretle',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: _currentUserUID)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Bildirimler yüklenemedi: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationItem(notifications[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Henüz bildirim yok',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Yeni mesaj, sipariş veya sistem\nbildirimleri burada görünecek',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String title = data['title']?.toString() ?? 'Bildirim';
    final String body = data['body']?.toString() ?? '';
    final String type = data['type']?.toString() ?? 'system';
    final String? referenceId = data['referenceId']?.toString();
    final bool isRead = data['isRead'] ?? false;
    final Timestamp? createdAt = data['createdAt'] as Timestamp?;

    IconData notificationIcon;
    Color iconColor;
    Color backgroundColor;

    switch (type) {
      case 'message':
        notificationIcon = Icons.chat_bubble;
        iconColor = Colors.blue;
        backgroundColor = Colors.blue[50]!;
        break;
      case 'order':
        notificationIcon = Icons.shopping_bag;
        iconColor = Colors.orange;
        backgroundColor = Colors.orange[50]!;
        break;
      case 'rental':
        notificationIcon = Icons.pets;
        iconColor = Theme.of(context).colorScheme.primary;
        backgroundColor = Theme.of(context).colorScheme.primaryContainer;
        break;
      case 'promotion':
        notificationIcon = Icons.local_offer;
        iconColor = Colors.purple;
        backgroundColor = Colors.purple[50]!;
        break;
      default:
        notificationIcon = Icons.info;
        iconColor = Colors.grey;
        backgroundColor = Colors.grey[100]!;
    }

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bildirimi Sil'),
            content: const Text('Bu bildirimi silmek istediğinizden emin misiniz?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sil', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        _deleteNotification(doc.id);
      },
      child: InkWell(
        onTap: () => _handleNotificationTap(doc.id, type, referenceId, isRead),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : backgroundColor,
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(notificationIcon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          _formatTimestamp(createdAt?.toDate() ?? DateTime.now()),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) =>
      AppFormatters.relativeTimestamp(timestamp);

  Future<void> _handleNotificationTap(
    String notificationId,
    String type,
    String? referenceId,
    bool isRead,
  ) async {
    // Mark as read if not already
    if (!isRead) {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
    }

    // Navigate based on type
    if (!mounted) return;

    switch (type) {
      case 'message':
        // The chat id alone is not enough to open a conversation: MessagePage
        // derives it from the two participant UIDs. Rather than silently doing
        // nothing when referenceId is missing, always land on the chat list.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatListPage(currentUserUID: _currentUserUID ?? ''),
          ),
        );
        break;
      case 'order':
        // There is no order detail screen yet, so the market is the closest
        // useful destination.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ShopPage()),
        );
        break;
      case 'rental':
        if (referenceId != null && referenceId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PetDetailPage(petId: referenceId, imagePath: ''),
            ),
          );
        } else {
          _showNoDestinationSnackBar();
        }
        break;
      default:
        // System or promotion - no specific navigation
        _showNoDestinationSnackBar();
        break;
    }
  }

  /// Tapping a notification should never look broken, even when there is
  /// nowhere to navigate to.
  void _showNoDestinationSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bu bildirim için detay bulunmuyor.')),
    );
  }

  Future<void> _markAllAsRead() async {
    try {
      // Firestore'da okunmamışları tek seferde çekip batch'e koyuyoruz.
      // Firestore batch sınırı 500 işlemdir; 500'den fazla bildirim varsa
      // tur tur devam ediyoruz, yoksa commit hata verirdi.
      while (true) {
        QuerySnapshot unreadNotifications = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: _currentUserUID)
            .where('isRead', isEqualTo: false)
            .limit(500)
            .get();

        if (unreadNotifications.docs.isEmpty) break;

        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in unreadNotifications.docs) {
          batch.update(doc.reference, {'isRead': true, 'readAt': FieldValue.serverTimestamp()});
        }
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tüm bildirimler okundu olarak işaretlendi')),
        );
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bildirimler güncellenemedi.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bildirim silinemedi.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
