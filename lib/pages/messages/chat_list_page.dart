import 'package:petguardian/pages/messages/message_page.dart';
import 'package:petguardian/stuff/formatters.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Cached profile of the other participant in a conversation.
class _UserInfo {
  final String fullName;
  final String photoURL;

  const _UserInfo({required this.fullName, required this.photoURL});
}

/// A conversation paired with the UID of the other participant.
class _Conversation {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String otherUID;

  const _Conversation(this.doc, this.otherUID);

  Map<String, dynamic> get data => doc.data();
  Timestamp? get lastMessageTimestamp => data['lastMessageTimestamp'] as Timestamp?;
  String get lastMessage => data['lastMessage']?.toString() ?? '';
  String get lastMessageType => data['lastMessageType']?.toString() ?? 'text';

  int unreadCountFor(String uid) {
    final raw = Map<String, dynamic>.from(data['unreadCount'] ?? {});
    final value = raw[uid];
    return value is int ? value : int.tryParse('$value') ?? 0;
  }
}

class ChatListPage extends StatefulWidget {
  final String currentUserUID;

  /// Injectable for tests; defaults to the ambient Firestore instance.
  final FirebaseFirestore? firestore;

  const ChatListPage({
    required this.currentUserUID,
    this.firestore,
    super.key,
  });

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isSearching = false;

  /// Profiles are read once and reused. Previously every row ran its own
  /// FutureBuilder, so each Firestore update re-read every user document.
  final Map<String, _UserInfo> _userCache = <String, _UserInfo>{};
  final Set<String> _pendingUIDs = <String>{};

  /// Uids the signed-in user has blocked, or been blocked by. Rows for these
  /// conversations show a lock glyph; the message page itself explains the
  /// state and offers the unblock action.
  final Set<String> _blockedCounterparts = <String>{};

  FirebaseFirestore get _db => widget.firestore ?? FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadBlockedCounterparts();
  }

  /// Two single-field equality queries (no composite index needed) cover both
  /// directions; the union is the set of blocked counterparts.
  Future<void> _loadBlockedCounterparts() async {
    try {
      final asBlocker = await _db
          .collection('blocks')
          .where('blockerUID', isEqualTo: widget.currentUserUID)
          .get();
      final asBlocked = await _db
          .collection('blocks')
          .where('blockedUID', isEqualTo: widget.currentUserUID)
          .get();
      if (!mounted) return;
      setState(() {
        _blockedCounterparts
          ..addAll(asBlocker.docs
              .map((d) => d.data()['blockedUID']?.toString() ?? ''))
          ..addAll(asBlocked.docs
              .map((d) => d.data()['blockerUID']?.toString() ?? ''))
          ..remove('');
      });
    } catch (e) {
      debugPrint('Engel durumu yüklenemedi: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
  }

  void _closeSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = false;
      _query = '';
    });
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  /// Fetches a participant profile once and caches it.
  void _ensureUserInfo(String uid) {
    if (uid.isEmpty || _userCache.containsKey(uid) || _pendingUIDs.contains(uid)) {
      return;
    }
    _pendingUIDs.add(uid);
    _db.collection('users').doc(uid).get().then((snapshot) {
      _pendingUIDs.remove(uid);
      if (!mounted) return;
      if (snapshot.exists) {
        final userData = snapshot.data()!;
        _userCache[uid] = _UserInfo(
          fullName: userData['fullName']?.toString() ?? 'İsimsiz',
          photoURL: userData['photoURL']?.toString() ?? '',
        );
      } else {
        _userCache[uid] = const _UserInfo(
          fullName: 'Kullanıcı bulunamadı',
          photoURL: '',
        );
      }
      setState(() {});
    }).catchError((Object error) {
      _pendingUIDs.remove(uid);
      // Cache a placeholder so the row stops spinning forever and the next
      // pull-to-refresh does not hammer a profile that keeps failing.
      if (!mounted) return;
      _userCache[uid] = const _UserInfo(
        fullName: 'Kullanıcı bilgisi alınamadı',
        photoURL: '',
      );
      setState(() {});
    });
  }

  List<_Conversation> _buildConversations(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final List<_Conversation> result = <_Conversation>[];

    for (final doc in docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? <String>[])
        ..remove(widget.currentUserUID);
      if (participants.isEmpty) continue;

      final otherUID = participants.first;
      _ensureUserInfo(otherUID);
      result.add(_Conversation(doc, otherUID));
    }

    // Most recent activity first, so conversations without a timestamp (or with
    // a pending serverTimestamp) stay at the bottom.
    result.sort((a, b) {
      final at = a.lastMessageTimestamp;
      final bt = b.lastMessageTimestamp;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

    if (_query.isEmpty) return result;

    return result.where((c) {
      final name = _userCache[c.otherUID]?.fullName.toLowerCase() ?? '';
      return name.contains(_query) || c.lastMessage.toLowerCase().contains(_query);
    }).toList();
  }

  bool get _searchIsWaitingOnNames => _query.isNotEmpty && _pendingUIDs.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _isSearching
            ? _buildSearchField()
            : const Text('Mesajlar'),
        elevation: 0,
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Sohbetlerde ara',
              onPressed: _startSearch,
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db
            .collection('messages')
            .where('participants', arrayContains: widget.currentUserUID)
            .orderBy('lastMessageTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          final conversations = _buildConversations(docs);

          // Names still loading: a match could be hiding behind an unresolved profile.
          if (_searchIsWaitingOnNames) {
            return const Center(child: CircularProgressIndicator());
          }

          if (conversations.isEmpty) {
            return _buildNoResultsState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Pull-to-refresh re-resolves the block set alongside the
              // stream's own live updates.
              await _loadBlockedCounterparts();
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              itemBuilder: (context, index) =>
                  _buildChatListItem(context, conversations[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: _onQueryChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: scheme.onSurface, fontSize: 16),
        cursorColor: scheme.primary,
        decoration: InputDecoration(
          hintText: 'İsim veya mesaj ara...',
          hintStyle: TextStyle(color: scheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
          border: InputBorder.none,
          suffixIcon: _query.isEmpty
              ? IconButton(
                  icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                  onPressed: _closeSearch,
                )
              : IconButton(
                  icon: Icon(Icons.clear, color: scheme.onSurfaceVariant),
                  onPressed: () {
                    _searchController.clear();
                    _onQueryChanged('');
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text('Hata oluştu: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Tekrar Dene'),
          ),
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
            'Henüz sohbet yok',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bir sohbet başlatmak için\nbir kullanıcı profiline gidin',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '"$_query" için sonuç bulunamadı',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _closeSearch,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Aramayı kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatListItem(BuildContext context, _Conversation conversation) {
    final _UserInfo? info = _userCache[conversation.otherUID];

    // Profile not resolved yet; _ensureUserInfo is already fetching it.
    if (info == null) return _buildLoadingTile();

    final int myUnreadCount = conversation.unreadCountFor(widget.currentUserUID);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MessagePage(
              recipientUID: conversation.otherUID,
              currentUserUID: widget.currentUserUID,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: info.photoURL.isNotEmpty && info.photoURL.startsWith('http')
                  ? NetworkImage(info.photoURL)
                  : null,
              child: info.photoURL.isEmpty || !info.photoURL.startsWith('http')
                  ? Text(
                      info.fullName.isNotEmpty ? info.fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : null,
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
                          info.fullName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(conversation.lastMessageTimestamp?.toDate() ?? DateTime.now()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (_typeIcon(conversation.lastMessageType)
                          case final IconData icon)
                        Icon(icon,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      if (conversation.lastMessageType != 'text') const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          conversation.lastMessageType == 'text'
                              ? conversation.lastMessage
                              : _getMessageTypeLabel(conversation.lastMessageType),
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: myUnreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_blockedCounterparts.contains(conversation.otherUID)) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: 'Bu sohbet engellendi',
                child: Icon(
                  Icons.block,
                  size: 16,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (myUnreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                constraints: const BoxConstraints(minWidth: 24),
                child: Text(
                  myUnreadCount > 99 ? '99+' : myUnreadCount.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: 100,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 4),
                Container(
                  height: 14,
                  width: 150,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) =>
      AppFormatters.relativeTimestamp(timestamp);

  String _getMessageTypeLabel(String type) =>
      AppFormatters.messageTypeLabel(type);

  /// Icon for a non-text message type, or null when the message is plain text.
  IconData? _typeIcon(String type) => AppFormatters.messageTypeIcon(type);
}