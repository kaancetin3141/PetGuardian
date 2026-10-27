import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:petguardian/services/firebase_messaging_service.dart';
import 'package:petguardian/stuff/formatters.dart';
import '../../stuff/app_network_image.dart';

class ChatMessage {
  final String id;
  final String message;
  final bool isMe;
  final DateTime timestamp;
  final String type; // text, image, location, pet_card, product_card
  final String? mediaUrl;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.message,
    required this.isMe,
    required this.timestamp,
    this.type = 'text',
    this.mediaUrl,
    this.isRead = false,
  });
}

class MessagePage extends StatefulWidget {
  final String recipientUID;
  final String currentUserUID;

  const MessagePage({
    required this.recipientUID,
    required this.currentUserUID,
    super.key,
  });

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  String recipientFullName = '';
  String recipientPhotoURL = '';
  String _chatId = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _chatId = _generateChatId(widget.currentUserUID, widget.recipientUID);
    // The chats security rules resolve the PARENT conversation document, so
    // reading the subcollection of a conversation that does not exist yet
    // (first message from a pet profile) would be rejected. Create it up
    // front with the exact shape the create rule accepts; set() with merge
    // makes this idempotent for conversations that already exist.
    _ensureConversation().whenComplete(() {
      if (!mounted) return;
      _loadRecipientData();
      _markMessagesAsRead();
    });
  }

  /// Creates the conversation document for a brand-new chat.
  ///
  /// `lastMessage: ''` satisfies the create rule's `is string` check while
  /// staying honest: nothing has been said yet, so the chat list sorts this
  /// conversation to the bottom (null timestamp) until the first message.
  /// The document is only written when it is missing — an unconditional
  /// merge would also reset the other participant's unread counter, which
  /// belongs to them, not to whoever opens the screen first.
  Future<void> _ensureConversation() async {
    try {
      final conversationRef =
          FirebaseFirestore.instance.collection('messages').doc(_chatId);
      final existing = await conversationRef.get();
      if (existing.exists) return;
      await conversationRef.set({
        'participants': [widget.currentUserUID, widget.recipientUID],
        'lastMessage': '',
        'lastMessageType': 'text',
        'senderUID': widget.currentUserUID,
        'recipientUID': widget.recipientUID,
        'unreadCount': <String, int>{},
      });
    } catch (e) {
      // Offline start: the stream below will retry once Firestore is back.
      debugPrint('Sohbet belgesi oluşturulamadı: $e');
    }
  }

  Future<void> _loadRecipientData() async {
    try {
      DocumentSnapshot recipientSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.recipientUID)
          .get();

      if (mounted) {
        setState(() {
          recipientFullName = recipientSnapshot['fullName']?.toString() ?? 'Kullanıcı';
          recipientPhotoURL = recipientSnapshot['photoURL']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading recipient data: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      // The conversation document may not exist yet on a first-ever chat;
      // message_page.dart creates it in _ensureConversation() before this
      // runs, but guard anyway so an offline start cannot surface a red
      // "could not mark as read" snackbar before anything was sent.
      final conversationRef =
          FirebaseFirestore.instance.collection('messages').doc(_chatId);
      final conversation = await conversationRef.get();
      if (!conversation.exists) return;

      // Update unread count in conversation document
      await conversationRef.update({
        'unreadCount.${widget.currentUserUID}': 0,
      });

      // Mark individual messages as read. The write is constrained to
      // {isRead, readAt} by the security rules, so the batch below is the only
      // shape it can take; a failure leaves the messages unread rather than
      // silently claiming they were read.
      final QuerySnapshot unreadMessages = await FirebaseFirestore.instance
          .collection('messages')
          .doc(_chatId)
          .collection('chats')
          .where('recipientUID', isEqualTo: widget.currentUserUID)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isEmpty) return;

      final WriteBatch batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesajlar okundu olarak işaretlenemedi.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: recipientPhotoURL.isNotEmpty && recipientPhotoURL.startsWith('http')
                  ? NetworkImage(recipientPhotoURL)
                  : null,
              child: recipientPhotoURL.isEmpty || !recipientPhotoURL.startsWith('http')
                  ? Text(
                      recipientFullName.isNotEmpty ? recipientFullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipientFullName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Online status placeholder
                  // Text(
                  //   'Çevrimiçi',
                  //   style: TextStyle(fontSize: 11, color: Colors.white70),
                  // ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              // TODO: Implement voice call
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              // TODO: Implement video call
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              // TODO: Handle menu actions
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'search', child: Text('Ara')),
              const PopupMenuItem(value: 'media', child: Text('Medya ve Dosyalar')),
              const PopupMenuItem(value: 'mute', child: Text('Sessize Al')),
              const PopupMenuItem(value: 'block', child: Text('Engelle')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .doc(_chatId)
                  .collection('chats')
                  .orderBy('timestamp', descending: true)
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
                        Text('Mesajlar yüklenemedi: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Group messages by date
                final groupedMessages = _groupMessagesByDate(docs);

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: groupedMessages.length,
                  itemBuilder: (context, index) {
                    final group = groupedMessages[index];
                    return Column(
                      children: [
                        _buildDateHeader(group.date),
                        ...group.messages.map((msg) => _buildMessageItem(msg)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
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
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '$recipientFullName ile sohbet başlatın',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'İlk mesajı siz gönderin',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  List<_MessageGroup> _groupMessagesByDate(List<QueryDocumentSnapshot> docs) {
    final Map<DateTime, List<ChatMessage>> groups = {};
    
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
      
      final message = ChatMessage(
        id: doc.id,
        message: data['message']?.toString() ?? '',
        isMe: data['senderUID'] == widget.currentUserUID,
        timestamp: timestamp,
        type: data['type']?.toString() ?? 'text',
        mediaUrl: data['mediaUrl']?.toString(),
        isRead: data['isRead'] ?? false,
      );
      
      groups.putIfAbsent(date, () => []).add(message);
    }

    // Sort groups by date (newest first since we're using reverse ListView)
    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    
    return sortedDates.map((date) => _MessageGroup(date: date, messages: groups[date]!)).toList();
  }

  Widget _buildDateHeader(DateTime date) {
    final label = AppFormatters.dayHeader(date);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(thickness: 0.5, color: Colors.grey)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const Expanded(child: Divider(thickness: 0.5, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    final isMe = message.isMe;
    final showAvatar = !isMe; // Show avatar only for received messages

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: recipientPhotoURL.isNotEmpty && recipientPhotoURL.startsWith('http')
                  ? NetworkImage(recipientPhotoURL)
                  : null,
              child: recipientPhotoURL.isEmpty || !recipientPhotoURL.startsWith('http')
                  ? Text(
                      recipientFullName.isNotEmpty ? recipientFullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ] else if (isMe) ...[
            const SizedBox(width: 40), // Space for avatar alignment
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Theme.of(context).colorScheme.primary : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Message content based on type
                  if (message.type == 'image' && message.mediaUrl != null)
                    _buildImageMessage(message.mediaUrl!)
                  else if (message.type == 'location')
                    _buildLocationMessage(message.message)
                  else if (message.type == 'pet_card')
                    _buildPetCardMessage(message.message)
                  else if (message.type == 'product_card')
                    _buildProductCardMessage(message.message)
                  else
                    Text(
                      message.message,
                      style: TextStyle(
                        fontSize: 15,
                        color: isMe ? Colors.white : Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Timestamp and read status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.grey[500],
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead ? Colors.blue : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe && showAvatar) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              // Current user avatar would go here
              child: Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.primary),
            ),
          ] else if (!isMe) ...[
            const SizedBox(width: 40),
          ],
        ],
      ),
    );
  }

  Widget _buildImageMessage(String imageUrl) {
    return GestureDetector(
      onTap: () {
        // TODO: Full screen image viewer
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AppNetworkImage(
          url: imageUrl,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          placeholderIcon: Icons.broken_image,
        ),
      ),
    );
  }

  Widget _buildLocationMessage(String locationData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.blue[700], size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '📍 Konum paylaşıldı',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.blue[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCardMessage(String petData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Row(
        children: [
          Icon(Icons.pets, color: Theme.of(context).colorScheme.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🐾 Hayvan kartı paylaşıldı',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCardMessage(String productData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_bag, color: Colors.orange[700], size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🛍️ Ürün kartı paylaşıldı',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.orange[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach button
            IconButton(
              icon: Icon(Icons.attach_file, color: Colors.grey[600]),
              onPressed: _showAttachmentOptions,
            ),
            // Camera button
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.camera_alt, color: Colors.grey[600]),
                    onPressed: () => _pickAndSendImage(ImageSource.camera),
                  ),
            // Text field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Mesaj yazın...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            SizedBox(width: 8),
            // Send button
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
              title: const Text('Galeriden Seç'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
              title: const Text('Fotoğraf Çek'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
              title: const Text('Konum Paylaş'),
              onTap: () {
                Navigator.pop(context);
                _sendLocation();
              },
            ),
            ListTile(
              leading: Icon(Icons.pets, color: Theme.of(context).colorScheme.primary),
              title: const Text('Hayvan Paylaş'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement pet card sharing
              },
            ),
            ListTile(
              leading: Icon(Icons.shopping_bag, color: Theme.of(context).colorScheme.primary),
              title: const Text('Ürün Paylaş'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement product card sharing
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (image == null) return;

      if (mounted) setState(() => _isLoading = true);

      // Upload to Firebase Storage. Reading the picked image as bytes instead of
      // wrapping it in a dart:io File keeps this working on web as well as mobile.
      final String fileName =
          'chat_images/$_chatId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      final bytes = await image.readAsBytes();
      final TaskSnapshot snapshot = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await _sendMessage(
        messageText: '📷 Fotoğraf',
        type: 'image',
        mediaUrl: downloadUrl,
      );
    } catch (e) {
      debugPrint('Error picking/sending image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf gönderilemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendLocation() async {
    // TODO: Implement location sharing using geolocator
    await _sendMessage(
      messageText: '📍 Konum paylaşıldı',
      type: 'location',
    );
  }

  Future<void> _sendMessage({
    String? messageText,
    String type = 'text',
    String? mediaUrl,
  }) async {
    final text = messageText ?? _messageController.text.trim();
    if (text.isEmpty && type == 'text') return;

    if (widget.currentUserUID == widget.recipientUID) return;

    HapticFeedback.lightImpact();

    try {
      final messageData = {
        'participants': [widget.currentUserUID, widget.recipientUID],
        'message': text,
        'type': type,
        'senderUID': widget.currentUserUID,
        'recipientUID': widget.recipientUID,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'mediaUrl': ?mediaUrl,
      };

      // Add message to subcollection
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(_chatId)
          .collection('chats')
          .add(messageData);

      // Update conversation document
      await FirebaseFirestore.instance.collection('messages').doc(_chatId).set({
        'participants': [widget.currentUserUID, widget.recipientUID],
        'lastMessage': type == 'text' ? text : _getMessageTypeLabel(type),
        'lastMessageType': type,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'senderUID': widget.currentUserUID,
        'recipientUID': widget.recipientUID,
        'recipientFullName': recipientFullName,
        'recipientPhotoURL': recipientPhotoURL,
        'unreadCount': {
          widget.recipientUID: FieldValue.increment(1),
        },
      }, SetOptions(merge: true));

      // Send FCM notification to recipient
      await FirebaseMessagingService.sendNotificationToUser(
        targetUserUID: widget.recipientUID,
        title: recipientFullName,
        body: type == 'text' ? text : _getMessageTypeLabel(type),
        data: {
          'chatId': _chatId,
          'senderUID': widget.currentUserUID,
          'type': 'message',
        },
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: $e')),
        );
      }
    }
  }

  String _getMessageTypeLabel(String type) =>
      AppFormatters.messageTypeLabel(type);

  String _generateChatId(String uid1, String uid2) {
    List<String> uids = [uid1, uid2]..sort();
    return uids.join('_');
  }
}

class _MessageGroup {
  final DateTime date;
  final List<ChatMessage> messages;

  _MessageGroup({required this.date, required this.messages});
}
