import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import 'album_screen.dart';
import 'extra_screens.dart';
import 'group_chat_setup_screen.dart';
import 'player_screen.dart';
import 'playlist_screen.dart';
import 'user_profile_screen.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:moodwave/widgets/mini_player.dart';

const _kPhrases = [
  ('Слушай это прямо сейчас', '🎵'),
  ('Напомнило о тебе', '💭'),
  ('Это точно про нас', '✨'),
  ('Для такой погоды', '🌧️'),
  ('Ты обязана это услышать', '🔥'),
  ('Почему это так больно', '😭'),
];

const _kReactions = [
  '❤️',
  '🔥',
  '😂',
  '🤯',
  '😍',
  '👀',
  '💀',
  '😢',
  '🎵',
  '👏'
];

String _formatChatTime(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try {
    final parsed = DateTime.parse(raw);
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  } catch (_) {
    return raw.length >= 16 ? raw.substring(11, 16) : '';
  }
}

class ChatScreen extends StatefulWidget {
  final int? matchId;
  final int? chatId;
  final int? groupChatId;
  final String partnerName;
  final int partnerId;
  final String? partnerAvatarUrl;
  final String? firebaseChatId;

  const ChatScreen({
    super.key,
    this.matchId,
    this.chatId,
    this.groupChatId,
    required this.partnerName,
    required this.partnerId,
    this.partnerAvatarUrl,
    this.firebaseChatId,
  }) : assert(matchId != null || chatId != null || groupChatId != null);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _mutedChatsKey = 'muted_chat_threads_v1';
  static const _deletedMsgsKey = 'deleted_msgs_for_me_v1';
  static const _lastReadKeyPrefix = 'last_read_v1_';
  final Set<String> _deletedForMe = {};
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<GlobalKey> _messageKeys = [];
  List<dynamic> _messages = [];
  bool _sending = false;
  bool _creatingListeningRoom = false;
  Timer? _pollTimer;
  Timer? _statusTimer;
  Timer? _searchHighlightTimer;
  int _lastCount = 0;
  int _pollCycle = 0;
  bool _chatMuted = false;
  int? _highlightedMessageIndex;
  String _highlightedQuery = '';
  Map<String, dynamic>? _partnerNowPlaying;
  bool _partnerOnline = false;
  String _partnerLastSeenAt = '';
  List<Map<String, dynamic>> _groupMembers = [];
  int _groupOwnerId = 0;
  Set<int> _groupAdminIds = {};
  String _groupTitle = '';
  String _groupAvatarUrl = '';
  String _groupUpdatedAt = '';
  String _firebaseChatId = '';
  List<Map<String, dynamic>> _groupAvatarHistory = [];
  List<Map<String, dynamic>> _pinnedMessages = [];
  final List<Map<String, dynamic>> _pendingMessages = [];
  final Set<String> _selectedMessageIds = {};
  bool _selectingMessages = false;
  bool _loadingMessages = false;
  bool _loadingGroupDetails = false;
  bool _loadingPins = false;
  String _lastMessagesSignature = '';
  String _lastPinsSignature = '';
  String _lastGroupSignature = '';
  String _lastDeliveredText = '';
  String _lastDeliveredAt = '';

  bool get _isGroupChat => widget.groupChatId != null;
  bool get _usesDirectThread =>
      !_isGroupChat && widget.matchId == null && widget.chatId != null;
  String get _conversationStorageKey => _isGroupChat
      ? 'group:${widget.groupChatId}'
      : _usesDirectThread
          ? 'thread:${widget.chatId}'
          : 'match:${widget.matchId}';
  String get _chatListKey => _isGroupChat
      ? 'g:${widget.groupChatId}'
      : _usesDirectThread
          ? 'c:${widget.chatId}'
          : 'm:${widget.matchId}';
  int get _currentUserId =>
      (context.read<AuthProvider>().user?['id'] as num?)?.toInt() ?? 0;

  Map<String, dynamic> _chatReturnPayload() {
    final now = DateTime.now().toUtc().toIso8601String();
    final deliveredAt = _lastDeliveredAt.isNotEmpty ? _lastDeliveredAt : now;
    return {
      'chat': {
        'chat_id': widget.chatId,
        'match_id': widget.matchId,
        'group_chat_id': widget.groupChatId,
        'chat_kind': _isGroupChat
            ? 'group'
            : widget.matchId != null
                ? 'match'
                : 'direct',
        if (_firebaseChatId.isNotEmpty) 'firebase_chat_id': _firebaseChatId,
        'created_at': deliveredAt,
        'updated_at': deliveredAt,
        'last_message_at': _lastDeliveredText.isNotEmpty ? deliveredAt : null,
        'last_message_preview':
            _lastDeliveredText.isNotEmpty ? _lastDeliveredText : null,
        'last_message_type': _lastDeliveredText.isNotEmpty ? 'text' : null,
        'partner': {
          'id': widget.partnerId,
          'display_name': widget.partnerName,
          'first_name': widget.partnerName,
          'avatar_url': widget.partnerAvatarUrl ?? '',
        },
      }
    };
  }

  void _popWithResult() {
    Navigator.of(context).pop(_chatReturnPayload());
  }

  Map<String, dynamic> _reactionMap(Map<String, dynamic> message) {
    final raw = message['reactions'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  String _messageSignature(Map<String, dynamic> message) {
    final reactions = _reactionMap(message);
    final reactionSignature = reactions.entries
        .map((entry) =>
            '${entry.key}:${((entry.value as List?) ?? const []).length}')
        .join(',');
    return [
      (message['message_id'] ?? '').toString(),
      (message['type'] ?? '').toString(),
      (message['sent_at'] ?? '').toString(),
      (message['text'] ?? '').toString(),
      (message['caption'] ?? '').toString(),
      reactionSignature,
    ].join('|');
  }

  String _messagesSignature(List<dynamic> messages) => messages
      .whereType<Map>()
      .map((item) => _messageSignature(Map<String, dynamic>.from(item)))
      .join('||');

  String _pinsSignature(List<Map<String, dynamic>> pins) => pins
      .map((pin) => [
            (pin['message_id'] ?? '').toString(),
            (pin['pinned_at'] ?? '').toString(),
            (pin['pinned_by'] ?? '').toString(),
            (pin['preview'] ?? '').toString(),
          ].join('|'))
      .join('||');

  Map<String, dynamic>? _pinForMessage(String messageId) {
    for (final pin in _pinnedMessages) {
      if ((pin['message_id'] ?? '').toString() == messageId) return pin;
    }
    return null;
  }

  bool _canUnpinPin(Map<String, dynamic>? pin) {
    return pin != null;
  }

  String _groupSignature({
    required List<Map<String, dynamic>> members,
    required int ownerId,
    required Set<int> adminIds,
    required String title,
    required String avatarUrl,
    required String updatedAt,
    required String firebaseChatId,
    required List<Map<String, dynamic>> avatarHistory,
  }) {
    final memberSignature = members
        .map((member) => [
              (member['id'] ?? '').toString(),
              (member['role'] ?? '').toString(),
              (member['display_name'] ?? '').toString(),
              (member['avatar_url'] ?? '').toString(),
            ].join('|'))
        .join('||');
    final avatarSignature = avatarHistory
        .map((item) => [
              (item['avatar_url'] ?? '').toString(),
              (item['created_at'] ?? '').toString(),
              (item['is_current'] ?? '').toString(),
            ].join('|'))
        .join('||');
    final orderedAdmins = adminIds.toList()..sort();
    return [
      title,
      avatarUrl,
      updatedAt,
      firebaseChatId,
      ownerId.toString(),
      orderedAdmins.join(','),
      memberSignature,
      avatarSignature,
    ].join('###');
  }

  @override
  void initState() {
    super.initState();
    MiniPlayerOverlayController.suppress();
    GlobalBottomNavController.hide();
    _firebaseChatId = widget.firebaseChatId ?? '';
    _loadMuteState();
    _loadDeletedForMe();
    _loadMessages();
    _loadPinned();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      _loadMessages();
      _pollCycle++;
      if (_pollCycle % 2 == 0) _loadPinned();
      if (_isGroupChat && _pollCycle % 4 == 0) _loadGroupDetails();
    });
    if (!_isGroupChat && widget.partnerId > 0) {
      _loadPartnerStatus();
      _statusTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _loadPartnerStatus());
    }
    if (_isGroupChat) _loadGroupDetails();
  }

  @override
  void dispose() {
    MiniPlayerOverlayController.unsuppress();
    GlobalBottomNavController.show();
    _pollTimer?.cancel();
    _statusTimer?.cancel();
    _searchHighlightTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPartnerStatus() async {
    if (!await ApiService().hasToken()) return;
    try {
      final data = await ApiService().getUserNowPlaying(widget.partnerId);
      if (!mounted) return;
      setState(() {
        _partnerNowPlaying =
            (data?['now_playing'] as Map?)?.cast<String, dynamic>();
        _partnerOnline = data?['is_online'] == true;
        _partnerLastSeenAt = (data?['last_seen_at'] ?? '').toString();
      });
    } catch (_) {}
  }

  Future<void> _loadGroupDetails() async {
    if (_loadingGroupDetails) return;
    if (!await ApiService().hasToken()) return;
    _loadingGroupDetails = true;
    try {
      final data = await ApiService().getGroupChatDetails(widget.groupChatId!);
      if (!mounted) return;
      final members = (data['members'] as List?)
              ?.map((m) => Map<String, dynamic>.from(m as Map))
              .toList() ??
          [];
      int ownerId = 0;
      final adminIds = <int>{};
      for (final m in members) {
        final uid = (m['id'] as num?)?.toInt() ?? 0;
        if (m['role'] == 'owner') ownerId = uid;
        if (m['role'] == 'admin') adminIds.add(uid);
      }
      final fid = (data['firebase_chat_id'] ?? '').toString();
      final avatarHistory = (data['avatar_history'] as List?)
              ?.map((item) => Map<String, dynamic>.from(item as Map))
              .toList() ??
          [];
      final shouldLoadPins = fid.isNotEmpty && fid != _firebaseChatId;
      final nextSignature = _groupSignature(
        members: members,
        ownerId: ownerId,
        adminIds: adminIds,
        title: (data['title'] ?? '').toString(),
        avatarUrl: (data['avatar_url'] ?? '').toString(),
        updatedAt: (data['updated_at'] ?? '').toString(),
        firebaseChatId: fid,
        avatarHistory: avatarHistory,
      );
      if (nextSignature != _lastGroupSignature) {
        _lastGroupSignature = nextSignature;
        setState(() {
          _groupMembers = members;
          _groupOwnerId = ownerId;
          _groupAdminIds = adminIds;
          _groupTitle = (data['title'] ?? '').toString();
          _groupAvatarUrl = (data['avatar_url'] ?? '').toString();
          _groupUpdatedAt = (data['updated_at'] ?? '').toString();
          _groupAvatarHistory = avatarHistory;
          if (fid.isNotEmpty) _firebaseChatId = fid;
        });
      } else if (fid.isNotEmpty && fid != _firebaseChatId) {
        setState(() => _firebaseChatId = fid);
      }
      if (shouldLoadPins) _loadPinned();
    } catch (_) {
    } finally {
      _loadingGroupDetails = false;
    }
  }

  Future<void> _loadDeletedForMe() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_deletedMsgsKey) ?? [];
    if (!mounted) return;
    setState(() => _deletedForMe.addAll(ids));
  }

  Future<void> _saveLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_lastReadKeyPrefix$_chatListKey',
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> _loadPinned() async {
    if (_firebaseChatId.isEmpty || _loadingPins) return;
    if (!await ApiService().hasToken()) return;
    _loadingPins = true;
    try {
      final pins = await ApiService().getPinnedMessages(_firebaseChatId);
      if (!mounted) return;
      final nextPins = pins
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList()
        ..sort((a, b) => (b['pinned_at'] as String? ?? '')
            .compareTo(a['pinned_at'] as String? ?? ''));
      final nextSignature = _pinsSignature(nextPins);
      if (nextSignature != _lastPinsSignature) {
        _lastPinsSignature = nextSignature;
        setState(() {
          _pinnedMessages = nextPins;
        });
      }
    } catch (_) {
    } finally {
      _loadingPins = false;
    }
  }

  Future<void> _pinMessage(String messageId, String preview) async {
    if (!await _ensureFirebaseChatId()) {
      _showActionError('Could not find this chat for pinning');
      return;
    }
    _applyLocalPin(messageId, preview);
    try {
      await ApiService().pinMessage(_firebaseChatId, messageId, preview);
      unawaited(_loadPinned());
    } catch (_) {
      unawaited(_loadPinned());
      _showActionError('Could not pin this message');
    }
  }

  Future<void> _unpinMessage(String messageId) async {
    if (!await _ensureFirebaseChatId()) {
      _showActionError('Could not find this chat for unpinning');
      return;
    }
    _applyLocalUnpin(messageId);
    try {
      await ApiService().unpinMessage(_firebaseChatId, messageId);
      unawaited(_loadPinned());
    } catch (_) {
      unawaited(_loadPinned());
      _showActionError('Could not unpin this message');
    }
  }

  Future<bool> _ensureFirebaseChatId() async {
    if (_firebaseChatId.isNotEmpty) return true;
    if (_isGroupChat) {
      await _loadGroupDetails();
    }
    return _firebaseChatId.isNotEmpty;
  }

  void _showActionError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        content: Text(message),
      ),
    );
  }

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
      if (_selectedMessageIds.isEmpty) _selectingMessages = false;
    });
  }

  Future<void> _forwardMessages(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    if (!await _ensureFirebaseChatId()) {
      _showActionError('Could not find this chat for forwarding');
      return;
    }
    final target = await _showForwardTargetSheet();
    if (target == null) return;
    try {
      await ApiService().forwardMessages(
        sourceFirebaseChatId: _firebaseChatId,
        messageIds: messageIds,
        targetKind: target.kind,
        targetId: target.id,
      );
      if (!mounted) return;
      setState(() {
        _selectingMessages = false;
        _selectedMessageIds.clear();
      });
      _showActionError('Forwarded');
    } catch (_) {
      _showActionError('Could not forward messages');
    }
  }

  Future<_ForwardTarget?> _showForwardTargetSheet() async {
    List<dynamic> chats = [];
    try {
      final cached = (await SharedPreferences.getInstance())
          .getString('social_cached_chats_v2');
      final decoded = cached == null ? null : jsonDecode(cached);
      if (decoded is List) chats = decoded;
    } catch (_) {}
    if (chats.whereType<Map>().isEmpty) {
      chats = await ApiService().getChats();
    } else {
      unawaited(ApiService().getChats().then((fresh) async {
        if (fresh.whereType<Map>().isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('social_cached_chats_v2', jsonEncode(fresh));
        }
      }).catchError((_) => null));
    }
    if (!mounted) return null;
    return showModalBottomSheet<_ForwardTarget>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Forward to',
                style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: chats.whereType<Map>().map((raw) {
                  final chat = Map<String, dynamic>.from(raw);
                  final partner =
                      (chat['partner'] as Map?)?.cast<String, dynamic>() ?? {};
                  final name = (partner['display_name'] ??
                          partner['first_name'] ??
                          partner['username'] ??
                          'Chat')
                      .toString();
                  final avatar = (partner['avatar_url'] ?? '').toString();
                  final target = _ForwardTarget.fromChat(chat);
                  if (target == null) return const SizedBox.shrink();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _Avatar(
                      initial: name.isNotEmpty ? name[0].toUpperCase() : 'C',
                      imageUrl: avatar,
                      size: 42,
                      fontSize: 15,
                    ),
                    title: Text(name,
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text)),
                    subtitle: Text(
                        target.kind == 'group' ? 'Group chat' : 'Direct chat',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppColors.text3)),
                    onTap: () => Navigator.pop(context, target),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _openRoomInviteFromMessage(Map<String, dynamic> msg) async {
    final rawId = msg['room_id'];
    var id =
        rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');
    if (id == null || id <= 0) {
      id = _roomIdFromInviteCode((msg['invite_code'] ?? '').toString());
    }
    if (id == null || id <= 0) {
      _showActionError('Room invite is missing room id');
      return;
    }
    try {
      final room = await ApiService().getRoomDetails(id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ListeningPartyScreen(room: room)),
      );
    } catch (e) {
      final detail = e.toString().contains('404')
          ? 'Room no longer active'
          : 'Could not open this room';
      _showActionError(detail);
    }
  }

  int? _roomIdFromInviteCode(String code) {
    final normalized = code.trim().toUpperCase();
    final match = RegExp(r'^MW-([0-9A-F]+)$').firstMatch(normalized);
    if (match == null) return null;
    return int.tryParse(match.group(1)!, radix: 16);
  }

  void _applyLocalPin(String messageId, String preview) {
    final next = [
      {
        'message_id': messageId,
        'preview': preview,
        'pinned_at': DateTime.now().toUtc().toIso8601String(),
        'pinned_by': _currentUserId,
      },
      ..._pinnedMessages.where((item) => item['message_id'] != messageId),
    ];
    setState(() {
      _pinnedMessages = next;
      _lastPinsSignature = _pinsSignature(next);
    });
  }

  void _applyLocalUnpin(String messageId) {
    final next = _pinnedMessages
        .where((item) => item['message_id'] != messageId)
        .toList();
    setState(() {
      _pinnedMessages = next;
      _lastPinsSignature = _pinsSignature(next);
    });
  }

  void _applyLocalReaction(String messageId, String emoji) {
    if (_currentUserId <= 0) return;
    final updatedMessages = _messages.map((raw) {
      final msg = Map<String, dynamic>.from(raw as Map);
      if ((msg['message_id'] ?? '').toString() != messageId) {
        return raw;
      }
      final rawReactions = msg['reactions'];
      final reactions = rawReactions is Map
          ? Map<String, dynamic>.from(rawReactions)
          : <String, dynamic>{};
      var hadSame = false;
      final next = <String, dynamic>{};
      for (final entry in reactions.entries) {
        final rawUsers = (entry.value as List?) ?? const [];
        final users = ((entry.value as List?) ?? const [])
            .map((user) => (user as num?)?.toInt() ?? 0)
            .where((userId) => userId > 0 && userId != _currentUserId)
            .toList();
        if (entry.key == emoji &&
            rawUsers
                .any((user) => user.toString() == _currentUserId.toString())) {
          hadSame = true;
        }
        if (users.isNotEmpty) next[entry.key] = users;
      }
      if (!hadSame) {
        next[emoji] = [...((next[emoji] as List?) ?? const []), _currentUserId];
      }
      msg['reactions'] = next;
      return msg;
    }).toList();
    setState(() {
      _messages = updatedMessages;
      _lastMessagesSignature = _messagesSignature(updatedMessages);
    });
  }

  Future<void> _submitReaction(String messageId, String emoji) async {
    _applyLocalReaction(messageId, emoji);
    try {
      if (_isGroupChat) {
        await ApiService().reactToGroupMessage(
          widget.groupChatId!,
          messageId,
          emoji,
        );
      } else if (_usesDirectThread) {
        await ApiService().reactToDirectMessage(
          widget.chatId!,
          messageId,
          emoji,
        );
      } else {
        await ApiService().reactToMessage(
          widget.matchId!,
          messageId,
          emoji,
        );
      }
      unawaited(_loadMessages());
    } catch (_) {
      unawaited(_loadMessages());
      _showActionError('Could not add reaction');
    }
  }

  Future<void> _deleteForMe(String messageId) async {
    _deletedForMe.add(messageId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_deletedMsgsKey, _deletedForMe.toList());
    if (!mounted) return;
    setState(() {
      _messages = _messages
          .where((m) => (m as Map)['message_id'] != messageId)
          .toList();
    });
  }

  Future<void> _loadMuteState() async {
    final prefs = await SharedPreferences.getInstance();
    final muted = prefs.getStringList(_mutedChatsKey) ?? const <String>[];
    if (!mounted) return;
    setState(() => _chatMuted = muted.contains(_conversationStorageKey));
  }

  Future<void> _toggleMuteConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final muted =
        (prefs.getStringList(_mutedChatsKey) ?? const <String>[]).toSet();
    if (_chatMuted) {
      muted.remove(_conversationStorageKey);
    } else {
      muted.add(_conversationStorageKey);
    }
    await prefs.setStringList(_mutedChatsKey, muted.toList());
    if (!mounted) return;
    setState(() => _chatMuted = !_chatMuted);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        content: Text(
          _chatMuted
              ? 'Notifications for this chat are muted'
              : 'Notifications for this chat are back on',
        ),
      ),
    );
  }

  Future<void> _loadMessages() async {
    if (_loadingMessages) return;
    if (!await ApiService().hasToken()) return;
    _loadingMessages = true;
    try {
      if (_pollCycle % 4 == 0) unawaited(ApiService().sendPresenceHeartbeat());
      final msgs = _isGroupChat
          ? await ApiService().getGroupChatMessages(widget.groupChatId!)
          : _usesDirectThread
              ? await ApiService().getDirectChatMessages(widget.chatId!)
              : await ApiService().getChatMessages(widget.matchId!);
      if (!mounted) return;
      final filtered = msgs
          .where((m) => !_deletedForMe.contains((m as Map)['message_id']))
          .toList();
      _pendingMessages.removeWhere(
        (pending) => filtered.any(
          (loaded) => (loaded as Map)['message_id'] == pending['message_id'],
        ),
      );
      final merged = [
        ...filtered,
        ..._pendingMessages.where((pending) => !filtered.any(
              (loaded) =>
                  (loaded as Map)['message_id'] == pending['message_id'],
            )),
      ];
      final needsScroll = merged.length != _lastCount;
      final nextSignature = _messagesSignature(merged);
      if (nextSignature != _lastMessagesSignature) {
        _lastMessagesSignature = nextSignature;
        setState(() {
          _messages = merged;
          _messageKeys = List<GlobalKey>.generate(
            merged.length,
            (_) => GlobalKey(),
            growable: false,
          );
          _lastCount = merged.length;
        });
      }
      _saveLastRead();
      if (needsScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (_) {
    } finally {
      _loadingMessages = false;
    }
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    HapticFeedback.lightImpact();
    final authUser =
        (context.read<AuthProvider>().user ?? const <String, dynamic>{});
    final myId = (authUser['id'] as num?)?.toInt() ?? 0;
    final optimisticId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final optimisticMessage = <String, dynamic>{
      'message_id': optimisticId,
      'type': 'text',
      'text': text,
      'sender_id': myId,
      'sender_name': (authUser['display_name'] ??
              authUser['first_name'] ??
              authUser['username'] ??
              '')
          .toString(),
      'sender_avatar_url': (authUser['avatar_url'] ?? '').toString(),
      'sent_at': DateTime.now().toUtc().toIso8601String(),
      'reactions': <String, dynamic>{},
    };
    setState(() => _sending = true);
    setState(() {
      _pendingMessages.add(optimisticMessage);
      _messages = [..._messages, optimisticMessage];
      _messageKeys = List<GlobalKey>.generate(
        _messages.length,
        (_) => GlobalKey(),
        growable: false,
      );
      _lastCount = _messages.length;
    });
    _textCtrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
    try {
      final response = _isGroupChat
          ? await ApiService().sendGroupTextMessage(widget.groupChatId!, text)
          : _usesDirectThread
              ? await ApiService().sendDirectTextMessage(widget.chatId!, text)
              : await ApiService().sendTextMessage(widget.matchId!, text);
      final deliveredId = (response['message_id'] ?? '').toString();
      final deliveredAt =
          (response['sent_at'] ?? optimisticMessage['sent_at']).toString();
      _lastDeliveredText = text;
      _lastDeliveredAt = deliveredAt;
      final pendingIndex =
          _pendingMessages.indexWhere((m) => m['message_id'] == optimisticId);
      if (pendingIndex >= 0) {
        _pendingMessages[pendingIndex] = {
          ..._pendingMessages[pendingIndex],
          'message_id': deliveredId.isNotEmpty ? deliveredId : optimisticId,
          'sent_at': deliveredAt,
        };
      }
      if (mounted) {
        setState(() {
          final messageIndex = _messages.indexWhere(
            (m) => (m as Map)['message_id'] == optimisticId,
          );
          if (messageIndex >= 0) {
            _messages[messageIndex] = {
              ...(_messages[messageIndex] as Map<String, dynamic>),
              'message_id': deliveredId.isNotEmpty ? deliveredId : optimisticId,
              'sent_at': deliveredAt,
            };
          }
        });
      }
      unawaited(_loadMessages());
    } catch (e) {
      if (!mounted) return;
      _pendingMessages.removeWhere((m) => m['message_id'] == optimisticId);
      setState(() {
        _messages.removeWhere((m) => (m as Map)['message_id'] == optimisticId);
        _messageKeys = List<GlobalKey>.generate(
          _messages.length,
          (_) => GlobalKey(),
          growable: false,
        );
        _lastCount = _messages.length;
      });
      _textCtrl.text = text;
      _textCtrl.selection =
          TextSelection.collapsed(offset: _textCtrl.text.length);
      _showSendError(e, fallback: 'Could not send message');
    }
    if (!mounted) return;
    setState(() => _sending = false);
  }

  Future<void> _sendTrackMessage(
    Map<String, dynamic> track, {
    String? phrase,
    String? phraseEmoji,
    String? note,
  }) async {
    var trackId =
        track['spotify_id']?.toString() ?? track['track_id']?.toString() ?? '';
    var title = track['title']?.toString() ?? '';
    var artist = track['artist']?.toString() ?? '';
    var coverUrl = track['cover_url']?.toString();
    var previewUrl = track['preview_url']?.toString();
    if (trackId.isEmpty && title.isNotEmpty) {
      final resolved = await ApiService().resolveTrack(
        title: title,
        artist: artist,
      );
      if (resolved != null) {
        track = resolved;
        trackId = resolved['spotify_id']?.toString() ??
            resolved['track_id']?.toString() ??
            '';
        title = resolved['title']?.toString() ?? title;
        artist = resolved['artist']?.toString() ?? artist;
        coverUrl = resolved['cover_url']?.toString() ?? coverUrl;
        previewUrl = resolved['preview_url']?.toString() ?? previewUrl;
      }
    }
    if (trackId.isEmpty) {
      throw Exception('Track could not be resolved');
    }
    if (_isGroupChat) {
      await ApiService().sendTrackInGroupChat(
        widget.groupChatId!,
        trackId: trackId,
        title: title,
        artist: artist,
        coverUrl: coverUrl,
        previewUrl: previewUrl,
        phrase: phrase,
        phraseEmoji: phraseEmoji,
        note: note,
      );
    } else if (_usesDirectThread) {
      await ApiService().sendTrackInDirectChat(
        widget.chatId!,
        trackId: trackId,
        title: title,
        artist: artist,
        coverUrl: coverUrl,
        previewUrl: previewUrl,
        phrase: phrase,
        phraseEmoji: phraseEmoji,
        note: note,
      );
    } else {
      await ApiService().sendTrackInChat(
        widget.matchId!,
        trackId: trackId,
        title: title,
        artist: artist,
        coverUrl: coverUrl,
        previewUrl: previewUrl,
        phrase: phrase,
        phraseEmoji: phraseEmoji,
        note: note,
      );
    }
  }

  void _showSendError(Object error, {required String fallback}) {
    if (error is DioException && error.response?.statusCode == 403) return;
    String message = fallback;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        message = data['detail'].toString();
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF7f1d1d),
      ),
    );
  }

  void _openTrackPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrackPickerSheet(
        onSend: (track, phrase, phraseEmoji, note) async {
          Navigator.pop(context);
          setState(() => _sending = true);
          try {
            await _sendTrackMessage(
              track,
              phrase: phrase,
              phraseEmoji: phraseEmoji,
              note: note,
            );
            await _loadMessages();
          } catch (e) {
            if (mounted) _showSendError(e, fallback: 'Could not send track');
          }
          if (mounted) setState(() => _sending = false);
        },
      ),
    );
  }

  void _openAlbumPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AlbumPickerSheet(
        onSend: (album, note) async {
          Navigator.pop(context);
          setState(() => _sending = true);
          try {
            if (_isGroupChat) {
              await ApiService().sendAlbumInGroupChat(
                widget.groupChatId!,
                albumId: album['id']?.toString() ?? '',
                title: album['title']?.toString() ?? '',
                artist: album['artist']?.toString() ?? '',
                coverUrl: album['cover_xl']?.toString(),
                note: note,
              );
            } else if (_usesDirectThread) {
              await ApiService().sendAlbumInDirectChat(
                widget.chatId!,
                albumId: album['id']?.toString() ?? '',
                title: album['title']?.toString() ?? '',
                artist: album['artist']?.toString() ?? '',
                coverUrl: album['cover_xl']?.toString(),
                note: note,
              );
            } else {
              await ApiService().sendAlbumInChat(
                widget.matchId!,
                albumId: album['id']?.toString() ?? '',
                title: album['title']?.toString() ?? '',
                artist: album['artist']?.toString() ?? '',
                coverUrl: album['cover_xl']?.toString(),
                note: note,
              );
            }
            await _loadMessages();
          } catch (e) {
            if (mounted) _showSendError(e, fallback: 'Could not send album');
          }
          if (mounted) setState(() => _sending = false);
        },
      ),
    );
  }

  void _openPlaylistPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaylistPickerSheet(
        onSend: (playlist, note) async {
          Navigator.pop(context);
          setState(() => _sending = true);
          try {
            final playlistId = (playlist['id'] as num?)?.toInt() ?? 0;
            final trackCount = (playlist['track_count'] as num?)?.toInt() ?? 0;
            if (_isGroupChat) {
              await ApiService().sendPlaylistInGroupChat(
                widget.groupChatId!,
                playlistId: playlistId,
                title: playlist['title']?.toString() ?? '',
                coverUrl: playlist['cover_url']?.toString(),
                trackCount: trackCount,
                note: note,
              );
            } else if (_usesDirectThread) {
              await ApiService().sendPlaylistInDirectChat(
                widget.chatId!,
                playlistId: playlistId,
                title: playlist['title']?.toString() ?? '',
                coverUrl: playlist['cover_url']?.toString(),
                trackCount: trackCount,
                note: note,
              );
            } else {
              await ApiService().sendPlaylistInChat(
                widget.matchId!,
                playlistId: playlistId,
                title: playlist['title']?.toString() ?? '',
                coverUrl: playlist['cover_url']?.toString(),
                trackCount: trackCount,
                note: note,
              );
            }
            await _loadMessages();
          } catch (e) {
            if (mounted) {
              _showSendError(e, fallback: 'Could not send playlist');
            }
          }
          if (mounted) setState(() => _sending = false);
        },
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 560,
      maxHeight: 560,
      imageQuality: 55,
    );
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    final noteCtrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImagePreviewSheet(
        bytes: bytes,
        controller: noteCtrl,
      ),
    );
    final caption = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _sending = true);
    try {
      if (_isGroupChat) {
        await ApiService().sendImageInGroupChat(
          widget.groupChatId!,
          imageDataUrl: dataUrl,
          caption: caption.isEmpty ? null : caption,
        );
      } else if (_usesDirectThread) {
        await ApiService().sendImageInDirectChat(
          widget.chatId!,
          imageDataUrl: dataUrl,
          caption: caption,
        );
      } else {
        await ApiService().sendImageInChat(
          widget.matchId!,
          imageDataUrl: dataUrl,
          caption: caption,
        );
      }
      await _loadMessages();
    } catch (e) {
      if (mounted) _showSendError(e, fallback: 'Could not send image');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttachmentOptionsSheet(
        onTrack: () {
          Navigator.pop(context);
          _openTrackPicker();
        },
        onAlbum: () {
          Navigator.pop(context);
          _openAlbumPicker();
        },
        onPlaylist: () {
          Navigator.pop(context);
          _openPlaylistPicker();
        },
        onImage: () {
          Navigator.pop(context);
          _pickAndSendImage();
        },
      ),
    );
  }

  void _openPartnerProfile() {
    if (_isGroupChat || widget.partnerId <= 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: widget.partnerId,
          initialUser: {
            'id': widget.partnerId,
            'display_name': widget.partnerName,
            'avatar_url': widget.partnerAvatarUrl,
          },
        ),
      ),
    );
  }

  Future<void> _openGroupAvatarGallery() async {
    if (!_isGroupChat) {
      _openPartnerProfile();
      return;
    }
    List<Map<String, dynamic>> avatars = _groupAvatarHistory;
    if (avatars.isEmpty) {
      try {
        final data =
            await ApiService().getGroupChatAvatarHistory(widget.groupChatId!);
        avatars =
            data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        if (mounted) {
          setState(() => _groupAvatarHistory = avatars);
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final imageItems = avatars
        .map((item) => <String, dynamic>{
              'image_url': (item['avatar_url'] ?? '').toString(),
              'caption': (item['is_current'] == true)
                  ? 'Current group avatar'
                  : 'Previous group avatar',
              'sent_at': item['created_at'],
            })
        .where((item) => (item['image_url'] as String).isNotEmpty)
        .toList();
    if (imageItems.isEmpty && _groupAvatarUrl.isNotEmpty) {
      imageItems.add({
        'image_url': _groupAvatarUrl,
        'caption': 'Current group avatar',
      });
    }
    if (imageItems.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SharedImageViewerScreen(
          images: imageItems,
          initialIndex: 0,
          title: _groupTitle.isNotEmpty ? _groupTitle : widget.partnerName,
        ),
      ),
    );
  }

  void _openConversationMenu() {
    final myId =
        (context.read<AuthProvider>().user?['id'] as num?)?.toInt() ?? 0;
    final amIOwner = _isGroupChat && _groupOwnerId == myId;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.74,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isGroupChat) ...[
                  _menuTile(
                    icon: Icons.groups_rounded,
                    label: 'Create group',
                    onTap: () {
                      Navigator.pop(context);
                      _createGroupChat();
                    },
                  ),
                  _menuTile(
                    icon: Icons.headphones_rounded,
                    label: 'Live Room',
                    onTap: () {
                      Navigator.pop(context);
                      _createListeningGroup();
                    },
                  ),
                ],
                if (_isGroupChat)
                  _menuTile(
                    icon: Icons.people_rounded,
                    label: 'Members',
                    trailing: '${_groupMembers.length}',
                    onTap: () {
                      Navigator.pop(context);
                      _openMembersSheet(myId, amIOwner);
                    },
                  ),
                if (_isGroupChat &&
                    (_groupAvatarUrl.isNotEmpty ||
                        _groupAvatarHistory.isNotEmpty))
                  _menuTile(
                    icon: Icons.history_rounded,
                    label: 'Avatar history',
                    onTap: () {
                      Navigator.pop(context);
                      _openGroupAvatarGallery();
                    },
                  ),
                if (_pinnedMessages.isNotEmpty)
                  _menuTile(
                    icon: Icons.push_pin_rounded,
                    label: 'Pinned messages',
                    trailing: '${_pinnedMessages.length}',
                    onTap: () {
                      Navigator.pop(context);
                      _showAllPinned();
                    },
                  ),
                if (_isGroupChat && (amIOwner || _groupAdminIds.contains(myId)))
                  _menuTile(
                    icon: Icons.edit_rounded,
                    label: 'Edit group',
                    onTap: () {
                      Navigator.pop(context);
                      _openEditGroupSheet();
                    },
                  ),
                _menuTile(
                  icon: Icons.folder_shared_rounded,
                  label: 'Shared media',
                  onTap: () {
                    Navigator.pop(context);
                    _openSharedContent();
                  },
                ),
                _menuTile(
                  icon: Icons.search_rounded,
                  label: 'Search in chat',
                  onTap: () {
                    Navigator.pop(context);
                    _openSearchInChat();
                  },
                ),
                _menuTile(
                  icon: _chatMuted
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  label: _chatMuted
                      ? 'Unmute notifications'
                      : 'Mute notifications',
                  onTap: () {
                    Navigator.pop(context);
                    _toggleMuteConversation();
                  },
                ),
                if (_isGroupChat)
                  _menuTile(
                    icon: Icons.exit_to_app_rounded,
                    label: 'Leave group',
                    onTap: () {
                      Navigator.pop(context);
                      _leaveGroupChat();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createListeningGroup() async {
    if (_creatingListeningRoom) return;
    setState(() => _creatingListeningRoom = true);
    Map<String, dynamic>? room;
    try {
      room = await showListeningRoomCreateSheet(
        context,
        initialName: '${widget.partnerName} Live Room',
        initialPublic: false,
      );
      if (room == null) {
        if (mounted) setState(() => _creatingListeningRoom = false);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _creatingListeningRoom = false);
      _showSendError(e, fallback: 'Could not create Live Room');
      return;
    }

    try {
      await ApiService().sendRoomInviteMessage(
        matchId: widget.matchId,
        chatId: widget.chatId,
        groupChatId: widget.groupChatId,
        room: room,
        inviteRole: 'listener',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creatingListeningRoom = false);
      _showSendError(e, fallback: 'Room created, but invite was not sent');
      return;
    }

    try {
      await _loadMessages();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _creatingListeningRoom = false);
    try {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ListeningPartyScreen(room: room!),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSendError(e, fallback: 'Room created, but could not open it');
    }
  }

  Future<void> _createGroupChat() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatSetupScreen(
          initialUsers: widget.partnerId > 0
              ? [
                  {
                    'id': widget.partnerId,
                    'display_name': widget.partnerName,
                    'username': '',
                    'avatar_url': widget.partnerAvatarUrl ?? '',
                  }
                ]
              : const [],
          sourceMatchId: widget.matchId,
          sourceChatId: widget.chatId,
        ),
      ),
    );
  }

  void _openSharedContent() {
    final myId =
        (context.read<AuthProvider>().user?['id'] as num?)?.toInt() ?? 0;
    final allMessages = _messages
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SharedContentScreen(
          messages: allMessages,
          partnerName: widget.partnerName,
          partnerId: widget.partnerId,
          currentUserId: myId,
          onJumpToMessage: (index) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (index < _messageKeys.length) {
                final key = _messageKeys[index];
                final ctx = key.currentContext;
                if (ctx != null) {
                  Scrollable.ensureVisible(ctx,
                      alignment: 0.5,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic);
                }
              }
            });
          },
        ),
      ),
    );
  }

  void _openSearchInChat() {
    final candidates = _messages
        .asMap()
        .entries
        .where((entry) => (entry.value as Map)['type']?.toString() == 'text')
        .map((entry) => _ChatSearchResult(
              index: entry.key,
              text: _searchableMessageText(
                Map<String, dynamic>.from(entry.value as Map),
              ),
              type: (entry.value as Map)['type']?.toString() ?? 'text',
              time:
                  _formatChatTime((entry.value as Map)['sent_at']?.toString()),
            ))
        .where((item) => item.text.trim().isNotEmpty)
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChatSearchScreen(
          partnerName: widget.partnerName,
          results: candidates,
          onJumpToMessage: (index, query) {
            Navigator.of(context).pop();
            _jumpToMessage(index, query: query);
          },
          typeIconBuilder: _messageTypeIcon,
        ),
      ),
    );
  }

  void _showMessageReactionSheet(String messageId,
      {required bool canDeleteAll, String preview = ''}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('React',
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2)),
            const SizedBox(height: 12),
            ...List.generate(2, (row) {
              final start = row * 5;
              final slice = _kReactions.skip(start).take(5).toList();
              return Padding(
                padding: EdgeInsets.only(bottom: row == 0 ? 8 : 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: slice.map((emoji) {
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await _submitReaction(messageId, emoji);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.glass,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 22))),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
            const SizedBox(height: 4),
            const Divider(color: AppColors.border, height: 1),
            Builder(builder: (ctx) {
              final pin = _pinForMessage(messageId);
              final isPinned = pin != null;
              final canUnpin = _canUnpinPin(pin);
              return ListTile(
                dense: true,
                leading: Icon(
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  color: AppColors.purpleLight,
                  size: 18,
                ),
                title: Text(
                  isPinned ? 'Unpin message' : 'Pin message',
                  style:
                      GoogleFonts.outfit(fontSize: 13, color: AppColors.text),
                ),
                enabled: !isPinned || canUnpin,
                onTap: isPinned && !canUnpin
                    ? null
                    : () {
                        Navigator.pop(context);
                        if (isPinned) {
                          _unpinMessage(messageId);
                        } else {
                          _pinMessage(messageId, preview);
                        }
                      },
              );
            }),
            ListTile(
              dense: true,
              leading: const Icon(Icons.forward_rounded,
                  color: AppColors.purpleLight, size: 18),
              title: Text('Forward',
                  style:
                      GoogleFonts.outfit(fontSize: 13, color: AppColors.text)),
              onTap: () {
                Navigator.pop(context);
                _forwardMessages([messageId]);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.checklist_rounded,
                  color: AppColors.text2, size: 18),
              title: Text('Select messages',
                  style:
                      GoogleFonts.outfit(fontSize: 13, color: AppColors.text)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectingMessages = true;
                  _selectedMessageIds
                    ..clear()
                    ..add(messageId);
                });
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.visibility_off_rounded,
                  color: AppColors.text2, size: 18),
              title: Text('Delete for me',
                  style:
                      GoogleFonts.outfit(fontSize: 13, color: AppColors.text)),
              onTap: () {
                Navigator.pop(context);
                _deleteForMe(messageId);
              },
            ),
            if (canDeleteAll)
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete_rounded,
                    color: Color(0xFFef4444), size: 18),
                title: Text('Delete for everyone',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: const Color(0xFFef4444))),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ApiService().deleteMessage(
                      matchId: widget.matchId,
                      chatId: widget.chatId,
                      groupChatId: widget.groupChatId,
                      messageId: messageId,
                    );
                    _loadMessages();
                  } catch (_) {}
                },
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildReactionBar(Map<String, dynamic> msg, {required bool isMe}) {
    final messageId = msg['message_id'] as String?;
    final reactions = _reactionMap(msg);
    if (messageId == null || reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Transform.translate(
      offset: const Offset(0, -1),
      child: Wrap(
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        spacing: 4,
        runSpacing: 4,
        children: reactions.entries.map((entry) {
          final emoji = entry.key;
          final users = (entry.value as List?) ?? const [];
          if (users.isEmpty) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => _submitReaction(messageId, emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.bg2.withOpacity(0.94),
                borderRadius: BorderRadius.circular(100),
                border:
                    Border.all(color: AppColors.purpleLight.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    '${users.length}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.text2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _leaveGroupChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Leave group?',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, color: AppColors.text)),
        content: Text(
            'You will leave this conversation. You can only come back with an invite.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Leave',
                style: GoogleFonts.outfit(color: const Color(0xFFef4444))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService().leaveGroupChat(widget.groupChatId!);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not leave group')),
      );
    }
  }

  void _openMembersSheet(int myId, bool amIOwner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GroupMembersSheet(
        members: _groupMembers,
        ownerId: _groupOwnerId,
        currentUserId: myId,
        amIOwner: amIOwner,
        groupChatId: widget.groupChatId!,
        onMemberRemoved: () {
          _loadGroupDetails();
        },
        onOwnerTransferred: (newOwnerId) {
          setState(() {
            _groupOwnerId = newOwnerId;
            for (final m in _groupMembers) {
              if ((m['id'] as num?)?.toInt() == newOwnerId) {
                m['role'] = 'owner';
              } else if ((m['id'] as num?)?.toInt() == myId) {
                m['role'] = 'member';
              }
            }
          });
        },
      ),
    );
  }

  void _openEditGroupSheet() {
    final titleCtrl = TextEditingController(text: _groupTitle);
    bool saving = false;
    Uint8List? pickedBytes;
    String pickedName = 'avatar.jpg';
    bool clearAvatar = false;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Group',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 16),
                _settingsField(
                  controller: titleCtrl,
                  hint: 'Group name',
                  icon: Icons.groups_rounded,
                ),
                const SizedBox(height: 10),
                // Avatar picker
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final img = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 400,
                          maxHeight: 400,
                          imageQuality: 80,
                        );
                        if (img == null) return;
                        final bytes = await img.readAsBytes();
                        setSS(() {
                          pickedBytes = bytes;
                          pickedName = img.name;
                          clearAvatar = false;
                        });
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(children: [
                          const SizedBox(width: 14),
                          if (pickedBytes != null && !clearAvatar)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(pickedBytes!,
                                  width: 32, height: 32, fit: BoxFit.cover),
                            )
                          else if (_groupAvatarUrl.isNotEmpty && !clearAvatar)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: buildMediaUrl(
                                  _groupAvatarUrl,
                                  version: _groupUpdatedAt.isNotEmpty
                                      ? _groupUpdatedAt
                                      : null,
                                ),
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.image_rounded,
                                  color: AppColors.text3,
                                  size: 22,
                                ),
                              ),
                            )
                          else
                            const Icon(Icons.image_rounded,
                                color: AppColors.text3, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              clearAvatar
                                  ? 'No photo'
                                  : pickedBytes != null
                                      ? 'Photo selected'
                                      : 'Change avatar photo',
                              style: GoogleFonts.outfit(
                                  fontSize: 14, color: AppColors.text3),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  if ((_groupAvatarUrl.isNotEmpty || pickedBytes != null) &&
                      !clearAvatar) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setSS(() {
                        clearAvatar = true;
                        pickedBytes = null;
                      }),
                      child: Container(
                        width: 46,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Color(0xFFef4444), size: 20),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: saving
                      ? null
                      : () async {
                          setSS(() => saving = true);
                          try {
                            String? newAvatarUrl;
                            if (pickedBytes != null) {
                              newAvatarUrl =
                                  await ApiService().uploadGroupChatAvatar(
                                widget.groupChatId!,
                                pickedBytes!,
                                pickedName,
                              );
                            } else if (clearAvatar) {
                              newAvatarUrl = '';
                            }
                            final result = await ApiService().updateGroupChat(
                              widget.groupChatId!,
                              title: titleCtrl.text.trim().isNotEmpty
                                  ? titleCtrl.text.trim()
                                  : null,
                              avatarUrl: newAvatarUrl,
                            );
                            if (newAvatarUrl != null &&
                                newAvatarUrl.isNotEmpty) {
                              await CachedNetworkImage.evictFromCache(
                                newAvatarUrl,
                              );
                            }
                            if (!mounted) return;
                            setState(() {
                              _groupTitle =
                                  (result['title'] ?? _groupTitle).toString();
                              _groupAvatarUrl =
                                  (result['avatar_url'] ?? '').toString();
                              _groupUpdatedAt = (result['updated_at'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty
                                  ? (result['updated_at'] ?? '').toString()
                                  : DateTime.now().toUtc().toIso8601String();
                            });
                            _loadGroupDetails();
                            Navigator.pop(ctx);
                          } catch (_) {
                            setSS(() => saving = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Could not update group')),
                            );
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: saving ? null : AppColors.primaryBtn,
                      color: saving ? AppColors.glass : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Save',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.outfit(color: AppColors.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: AppColors.text3),
          prefixIcon: Icon(icon, color: AppColors.text3, size: 18),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        ),
      ),
    );
  }

  String _searchableMessageText(Map<String, dynamic> msg) {
    final parts = <String>[
      msg['text']?.toString() ?? '',
      msg['caption']?.toString() ?? '',
      msg['note']?.toString() ?? '',
      msg['track_title']?.toString() ?? '',
      msg['track_artist']?.toString() ?? '',
      msg['album_title']?.toString() ?? '',
      msg['album_artist']?.toString() ?? '',
      msg['playlist_title']?.toString() ?? '',
    ];
    return parts.where((part) => part.trim().isNotEmpty).join(' · ');
  }

  IconData _messageTypeIcon(String type) {
    switch (type) {
      case 'track':
        return Icons.music_note_rounded;
      case 'album':
        return Icons.album_rounded;
      case 'playlist':
        return Icons.queue_music_rounded;
      case 'image':
        return Icons.image_rounded;
      default:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  void _jumpToMessage(int index, {String query = ''}) {
    if (index < 0 || index >= _messageKeys.length) return;
    _searchHighlightTimer?.cancel();
    setState(() {
      _highlightedMessageIndex = index;
      _highlightedQuery = query.trim();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _messageKeys[index].currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
      }
    });
    _searchHighlightTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() {
        _highlightedMessageIndex = null;
        _highlightedQuery = '';
      });
    });
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    String? trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.purpleLight),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
            if (trailing != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trailing,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.purpleLight,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthProvider>().user?['id'];
    final displayName = _isGroupChat && _groupTitle.isNotEmpty
        ? _groupTitle
        : widget.partnerName;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final partnerAvatarUrl = _isGroupChat && _groupAvatarUrl.isNotEmpty
        ? buildMediaUrl(
            _groupAvatarUrl,
            version: _groupUpdatedAt.isNotEmpty ? _groupUpdatedAt : null,
          )
        : (widget.partnerAvatarUrl ?? '');

    return WillPopScope(
      onWillPop: () async {
        _popWithResult();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(children: [
          _buildHeader(initial, partnerAvatarUrl, displayName),
          const _ChatNowPlayingBar(),
          Container(height: 1, color: AppColors.border),
          if (_pinnedMessages.isNotEmpty) _buildPinnedBanner(),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    controller: _scrollCtrl,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i] as Map<String, dynamic>;
                      final isMe = msg['sender_id'] == myId;
                      final type = msg['type'] ?? 'text';
                      final messageId = msg['message_id'] as String?;
                      final senderName = _isGroupChat && !isMe
                          ? (msg['sender_name']?.toString().trim().isNotEmpty ??
                                  false)
                              ? msg['sender_name'].toString()
                              : widget.partnerName
                          : widget.partnerName;
                      final bubbleInitial = senderName.isNotEmpty
                          ? senderName[0].toUpperCase()
                          : initial;
                      final bubbleAvatarUrl = _isGroupChat && !isMe
                          ? (msg['sender_avatar_url'] ?? '').toString()
                          : partnerAvatarUrl;
                      final messageFooter =
                          type != 'track' && _reactionMap(msg).isNotEmpty
                              ? _buildReactionBar(msg, isMe: isMe)
                              : null;
                      Widget child = switch (type) {
                        'track' => _TrackMessage(
                            msg: msg,
                            isMe: isMe,
                            partnerInitial: bubbleInitial,
                            partnerAvatarUrl: bubbleAvatarUrl,
                            matchId: widget.matchId,
                            chatId: widget.chatId,
                            groupChatId: widget.groupChatId,
                            useGroupChat: _isGroupChat,
                            useDirectThread: _usesDirectThread,
                            onReacted: _loadMessages,
                          ),
                        'album' => _AlbumMessage(
                            msg: msg,
                            isMe: isMe,
                            partnerInitial: bubbleInitial,
                            partnerAvatarUrl: bubbleAvatarUrl,
                            footer: messageFooter,
                          ),
                        'playlist' => _PlaylistMessage(
                            msg: msg,
                            isMe: isMe,
                            partnerInitial: bubbleInitial,
                            partnerAvatarUrl: bubbleAvatarUrl,
                            footer: messageFooter,
                          ),
                        'profile' => _ProfileMessage(
                            msg: msg,
                            isMe: isMe,
                            partnerInitial: bubbleInitial,
                            partnerAvatarUrl: bubbleAvatarUrl,
                          ),
                        'image' => _ImageMessage(
                            msg: msg,
                            isMe: isMe,
                            partnerInitial: bubbleInitial,
                            partnerAvatarUrl: bubbleAvatarUrl,
                            footer: messageFooter,
                          ),
                        'room_invite' => _RoomInviteMessage(
                            msg: msg,
                            isMe: isMe,
                            partnerInitial: bubbleInitial,
                            partnerAvatarUrl: bubbleAvatarUrl,
                            footer: messageFooter,
                          ),
                        _ => _TextMessage(
                            msg: msg,
                            isMe: isMe,
                            partnerInitial: bubbleInitial,
                            partnerAvatarUrl: bubbleAvatarUrl,
                            footer: messageFooter,
                            highlighted: i == _highlightedMessageIndex,
                            highlightQuery: i == _highlightedMessageIndex
                                ? _highlightedQuery
                                : '',
                          ),
                      };
                      if (messageId != null) {
                        final canDeleteAll = isMe ||
                            (_isGroupChat &&
                                (myId == _groupOwnerId ||
                                    _groupAdminIds.contains(myId)));
                        final msgPreview = type == 'text'
                            ? (msg['text'] as String? ?? '').substring(
                                0,
                                ((msg['text'] as String? ?? '').length)
                                    .clamp(0, 60))
                            : '[$type]';
                        child = GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _selectingMessages
                              ? () => _toggleMessageSelection(messageId)
                              : type == 'room_invite'
                                  ? () => _openRoomInviteFromMessage(msg)
                                  : null,
                          onDoubleTap: _selectingMessages
                              ? null
                              : () => _showMessageReactionSheet(messageId,
                                  canDeleteAll: canDeleteAll,
                                  preview: msgPreview),
                          onLongPress: _selectingMessages
                              ? () => _toggleMessageSelection(messageId)
                              : () => _showMessageReactionSheet(messageId,
                                  canDeleteAll: canDeleteAll,
                                  preview: msgPreview),
                          child: Stack(children: [
                            child,
                            if (_selectedMessageIds.contains(messageId))
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.purpleLight
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppColors.purpleLight
                                            .withOpacity(0.55),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ]),
                        );
                      }
                      // Admin badge for group chats
                      final senderId = (msg['sender_id'] as num?)?.toInt();
                      final isOwnerMsg = _isGroupChat &&
                          _groupOwnerId > 0 &&
                          senderId == _groupOwnerId;
                      final isAdminMsg = _isGroupChat &&
                          senderId != null &&
                          _groupAdminIds.contains(senderId);
                      if (isOwnerMsg || isAdminMsg) {
                        final badge = Container(
                          margin: EdgeInsets.only(
                            bottom: 3,
                            left: isMe ? 0 : 44,
                            right: isMe ? 8 : 0,
                          ),
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.purpleDark.withOpacity(0.28),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              isOwnerMsg ? 'owner' : 'admin',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isOwnerMsg
                                    ? AppColors.pink
                                    : AppColors.purpleLight,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        );
                        child = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [badge, child],
                        );
                      }
                      return Padding(
                        key: i < _messageKeys.length ? _messageKeys[i] : null,
                        padding: const EdgeInsets.only(bottom: 10),
                        child: child,
                      );
                    },
                  ),
          ),
          _selectingMessages ? _buildSelectionBar() : _buildComposer(),
        ]),
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          TextButton(
            onPressed: () => setState(() {
              _selectingMessages = false;
              _selectedMessageIds.clear();
            }),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppColors.text2)),
          ),
          const Spacer(),
          Text('${_selectedMessageIds.length} selected',
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const Spacer(),
          GestureDetector(
            onTap: _selectedMessageIds.isEmpty
                ? null
                : () => _forwardMessages(_selectedMessageIds.toList()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.gradPurple,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.forward_rounded,
                    size: 17, color: Colors.white),
                const SizedBox(width: 6),
                Text('Forward',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader(
      String initial, String partnerAvatarUrl, String displayName) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.26),
              blurRadius: 14,
              offset: const Offset(0, 5))
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Row(children: [
            GestureDetector(
              onTap: _popWithResult,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.86),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border)),
                child: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.text, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap:
                  _isGroupChat ? _openGroupAvatarGallery : _openPartnerProfile,
              child: _Avatar(
                initial: initial,
                imageUrl: partnerAvatarUrl,
                size: 60,
                fontSize: 21,
                borderWidth: 2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _openPartnerProfile,
                behavior: HitTestBehavior.opaque,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text)),
                      if (_isGroupChat)
                        Text(
                          _groupMembers.isNotEmpty
                              ? 'Group · ${_groupMembers.length} members'
                              : 'Group chat',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.purpleLight),
                        )
                      else
                        _buildPartnerStatus(),
                    ]),
              ),
            ),
            GestureDetector(
              onTap: _openConversationMenu,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.86),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.more_horiz_rounded,
                    size: 20, color: AppColors.purpleLight),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPartnerStatus() {
    final np = _partnerNowPlaying;
    if (np != null && np.isNotEmpty) {
      final artist = np['artist']?.toString() ?? '';
      final title = np['title']?.toString() ?? '';
      final label = artist.isNotEmpty
          ? 'Now listening to $artist'
          : title.isNotEmpty
              ? 'Now listening to $title'
              : null;
      if (label != null) {
        return Row(children: [
          const Icon(Icons.music_note_rounded, size: 11, color: AppColors.pink),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.pink),
            ),
          ),
        ]);
      }
    }
    if (_partnerOnline) {
      return Text('Online',
          style:
              GoogleFonts.outfit(fontSize: 12, color: AppColors.purpleLight));
    }
    if (_partnerLastSeenAt.isNotEmpty) {
      return Text('Last seen ${_formatLastSeen(_partnerLastSeenAt)}',
          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3));
    }
    return const SizedBox.shrink();
  }

  String _formatLastSeen(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  Widget _buildPinnedBanner() {
    final latest = _pinnedMessages.first;
    final preview = (latest['preview'] as String? ?? '').trim();
    final count = _pinnedMessages.length;
    return GestureDetector(
      onTap: () {
        if (count > 1) {
          _showAllPinned();
        } else {
          _scrollToMessage(latest['message_id'] as String? ?? '');
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.purple.withOpacity(0.22),
              AppColors.surface,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.purpleLight.withOpacity(0.24)),
          boxShadow: [
            BoxShadow(
              color: AppColors.purpleDark.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.purpleLight.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.push_pin_rounded,
                size: 16, color: AppColors.purpleLight),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count > 1 ? 'Pinned messages · $count' : 'Pinned message',
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.purpleLight),
                ),
                if (preview.isNotEmpty)
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text),
                  ),
              ],
            ),
          ),
          Text(
            count > 1 ? 'All pins' : 'Open',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.text3,
            ),
          ),
        ]),
      ),
    );
  }

  void _showAllPinned() {
    if (_pinnedMessages.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              const Icon(Icons.push_pin_rounded,
                  size: 16, color: AppColors.purpleLight),
              const SizedBox(width: 8),
              Text('Pinned messages',
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
            ]),
          ),
          const Divider(color: AppColors.border, height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _pinnedMessages.length,
              itemBuilder: (ctx, i) {
                final pin = _pinnedMessages[i];
                final msgId = pin['message_id'] as String? ?? '';
                final prev = (pin['preview'] as String? ?? '').trim();
                final canUnpin = _canUnpinPin(pin);
                return ListTile(
                  leading: const Icon(Icons.push_pin_rounded,
                      size: 16, color: AppColors.purpleLight),
                  title: Text(
                    prev.isNotEmpty ? prev : '[message]',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        GoogleFonts.outfit(fontSize: 13, color: AppColors.text),
                  ),
                  subtitle: Text(
                    _formatChatTime((pin['pinned_at'] ?? '').toString()),
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.text3),
                  ),
                  trailing: canUnpin
                      ? IconButton(
                          icon: const Icon(Icons.push_pin_outlined,
                              size: 16, color: AppColors.text3),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _unpinMessage(msgId);
                          },
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    _scrollToMessage(msgId);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _scrollToMessage(String messageId) {
    final idx =
        _messages.indexWhere((m) => (m as Map)['message_id'] == messageId);
    if (idx < 0) return;
    _jumpToMessage(idx, query: '');
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.gradMixed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.purple.withOpacity(0.4), blurRadius: 24)
              ],
            ),
            child:
                const Center(child: Text('🎵', style: TextStyle(fontSize: 30))),
          ),
          const SizedBox(height: 18),
          Text('Say hi to ${widget.partnerName}!',
              style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          Text('You matched on music taste',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text3)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _openAttachmentMenu,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.gradPurple,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.music_note_rounded,
                    size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text('Send a track',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        border: const Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      padding: EdgeInsets.fromLTRB(
          14, 10, 14, MediaQuery.of(context).viewInsets.bottom + 18),
      child: Row(children: [
        // Track button
        GestureDetector(
          onTap: _openAttachmentMenu,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.glass,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.add_rounded,
                size: 22, color: AppColors.purpleLight),
          ),
        ),
        const SizedBox(width: 8),
        // Text input
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _textCtrl,
              style: GoogleFonts.outfit(fontSize: 15, color: AppColors.text),
              maxLength: 100,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle:
                    GoogleFonts.outfit(fontSize: 15, color: AppColors.text3),
                border: InputBorder.none,
                counterText: '',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send button
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.gradPurple,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.purpleDark.withOpacity(0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: _sending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }
}

// ─── Text Message ─────────────────────────────────────────────────────────────

class _ForwardedLabel extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;

  const _ForwardedLabel({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (msg['forwarded'] != true) return const SizedBox.shrink();
    final hidden = msg['forwarded_profile_hidden'] == true;
    final name = (msg['forwarded_from_name'] ?? '').toString();
    final userId = (msg['forwarded_from_user_id'] as num?)?.toInt() ?? 0;
    final canOpenProfile = !hidden && userId > 0;
    final label =
        hidden || name.isEmpty ? 'Forwarded message' : 'Forwarded from $name';
    return Padding(
      padding: EdgeInsets.only(
        bottom: 3,
        left: isMe ? 0 : 2,
        right: isMe ? 2 : 0,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canOpenProfile
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                      userId: userId,
                      initialUser: {
                        'id': userId,
                        'display_name': name,
                      },
                    ),
                  ),
                )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forward_rounded,
                size: 12, color: AppColors.purpleLight),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.purpleLight,
                    decoration:
                        canOpenProfile ? TextDecoration.underline : null,
                    decorationColor: AppColors.purpleLight)),
          ],
        ),
      ),
    );
  }
}

class _TextMessage extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String partnerInitial;
  final String partnerAvatarUrl;
  final Widget? footer;
  final bool highlighted;
  final String highlightQuery;
  const _TextMessage(
      {required this.msg,
      required this.isMe,
      required this.partnerInitial,
      required this.partnerAvatarUrl,
      this.footer,
      this.highlighted = false,
      this.highlightQuery = ''});

  Map<String, String>? _inviteCard(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    // New format: 💬 Name создал(а) группу «Title»! Присоединяйся с кодом: 42
    final groupMatch = RegExp(
      r'^(?:💬\s*)?(.+?)(?:\s+создал[аи]?\s+группу\s+«.+?»!?\s+Присоединяйся с кодом:|'
      r'\s+created a group chat!?\s*Join with code:|'
      r'\s+Join with code:)\s*(\d+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(trimmed);
    if (groupMatch != null) {
      final author = (groupMatch.group(1) ?? '').trim();
      return {
        'kind': 'group',
        'title':
            author.isNotEmpty ? '$author invites to group' : 'Group invite',
        'code': (groupMatch.group(2) ?? '').trim(),
      };
    }
    final roomMatch = RegExp(
      r'^(?:🎵\s*)?Listening room created!\s*Invite code:\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (roomMatch != null) {
      return {
        'kind': 'room',
        'title': 'Live Room invite',
        'role': 'Listener',
        'code': (roomMatch.group(1) ?? '').trim(),
      };
    }
    final modernRoomMatch = RegExp(
      r'^(?:🎧\s*)?(.+?)\s+invites you to listen together\s+Room:\s*(.+?)\s+Role:\s*(.+?)\s+Code:\s*(MW-[A-Fa-f0-9]+)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(trimmed.replaceAll('\n', ' '));
    if (modernRoomMatch != null) {
      final role = (modernRoomMatch.group(3) ?? 'Listener').trim();
      return {
        'kind': 'room',
        'title': '${modernRoomMatch.group(1)?.trim() ?? 'Someone'} invites you',
        'room': (modernRoomMatch.group(2) ?? 'Live Room').trim(),
        'role': role,
        'code': (modernRoomMatch.group(4) ?? '').trim(),
      };
    }
    return null;
  }

  InlineSpan _buildHighlightedText(String text, TextStyle baseStyle) {
    final query = highlightQuery.trim();
    if (!highlighted || query.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final matches = <int>[];
    var start = 0;
    while (start < lower.length) {
      final idx = lower.indexOf(q, start);
      if (idx < 0) break;
      matches.add(idx);
      start = idx + q.length;
    }
    if (matches.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final idx in matches) {
      if (idx > cursor) {
        children.add(TextSpan(text: text.substring(cursor, idx)));
      }
      children.add(
        TextSpan(
          text: text.substring(idx, idx + q.length),
          style: baseStyle.copyWith(
            color: AppColors.purpleLight,
            fontWeight: FontWeight.w800,
            backgroundColor: AppColors.purpleLight.withOpacity(0.18),
          ),
        ),
      );
      cursor = idx + q.length;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(
      style: baseStyle,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = msg['text'] ?? '';
    final sentAt = msg['sent_at'] as String? ?? '';
    final timeStr = _formatChatTime(sentAt);
    final inviteCard = _inviteCard(text.toString());
    final forwarded = _ForwardedLabel(msg: msg, isMe: isMe);

    if (inviteCard != null) {
      final isGroup = inviteCard['kind'] == 'group';
      final code = inviteCard['code'] ?? '';
      final role = inviteCard['role'] ?? '';
      final roomTitle = inviteCard['room'] ?? '';

      Future<void> handleTap() async {
        if (isGroup) {
          final groupChatId = int.tryParse(code);
          if (groupChatId == null) return;
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                groupChatId: groupChatId,
                partnerName: inviteCard['title'] ?? 'Group',
                partnerId: 0,
              ),
            ),
          );
          return;
        }
        if (!code.toUpperCase().startsWith('MW-')) return;
        final hex = code.substring(3);
        final roomId = int.tryParse(hex, radix: 16);
        if (roomId == null) return;
        try {
          final room = await ApiService().getRoomDetails(roomId);
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ListeningPartyScreen(room: room),
            ),
          );
        } catch (e) {
          if (!context.mounted) return;
          final detail = e.toString().contains('404')
              ? 'Room no longer active'
              : 'Could not open room';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(detail, style: GoogleFonts.outfit(fontSize: 13)),
            backgroundColor: AppColors.surface,
          ));
        }
      }

      final bubble = GestureDetector(
        onTap: handleTap,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: isGroup ? AppColors.primaryBtn : AppColors.gradPurple,
            borderRadius: BorderRadius.circular(18),
            border: highlighted
                ? Border.all(
                    color: AppColors.purpleLight.withOpacity(0.6),
                    width: 1.4,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.purpleDark.withOpacity(0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isGroup ? Icons.groups_rounded : Icons.headphones_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inviteCard['title'] ?? '',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (roomTitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(roomTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.76))),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (!isGroup && role.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(role,
                                    style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                code,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Нажми чтобы войти →',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (isMe) {
        return Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              forwarded,
              bubble,
              if (timeStr.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  timeStr,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: AppColors.text3,
                  ),
                ),
              ],
            ],
          ),
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Avatar(initial: partnerInitial, imageUrl: partnerAvatarUrl),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                forwarded,
                bubble,
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    timeStr,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: AppColors.text3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    if (isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          forwarded,
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: AppColors.gradPurple,
              border: highlighted
                  ? Border.all(
                      color: AppColors.purpleLight.withOpacity(0.6),
                      width: 1.4,
                    )
                  : null,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                    color: AppColors.purpleDark.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: RichText(
              text: _buildHighlightedText(
                text,
                GoogleFonts.outfit(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 2),
            footer!,
          ],
          if (timeStr.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(timeStr,
                style:
                    GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
          ],
        ]),
      );
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _Avatar(initial: partnerInitial, imageUrl: partnerAvatarUrl),
      const SizedBox(width: 8),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          forwarded,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: highlighted
                  ? AppColors.purple.withOpacity(0.14)
                  : AppColors.surface2,
              border: Border.all(
                color: highlighted
                    ? AppColors.purpleLight.withOpacity(0.55)
                    : AppColors.border,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: RichText(
              text: _buildHighlightedText(
                text,
                GoogleFonts.outfit(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 2),
            footer!,
          ],
          if (timeStr.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(timeStr,
                style:
                    GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
          ],
        ]),
      ),
    ]);
  }
}

class _RoomInviteMessage extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String partnerInitial;
  final String partnerAvatarUrl;
  final Widget? footer;

  const _RoomInviteMessage({
    required this.msg,
    required this.isMe,
    required this.partnerInitial,
    required this.partnerAvatarUrl,
    this.footer,
  });

  Future<void> _openRoom(BuildContext context) async {
    final rawId = msg['room_id'];
    var id =
        rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');
    if (id == null || id <= 0) {
      id = _roomIdFromInviteCode((msg['invite_code'] ?? '').toString());
    }
    if (id == null || id <= 0) {
      if (!context.mounted) return;
      _inviteSnack(context, 'Invalid room invite', error: true);
      return;
    }
    try {
      var room = await ApiService().getRoomDetails(id);
      final myStatus = (room['my_status'] ?? '').toString();
      final canAutoJoin = myStatus != 'connected' &&
          (room['is_public'] == true || myStatus == 'approved');
      if (canAutoJoin) {
        try {
          await ApiService().joinRoom(id);
          room = await ApiService().getRoomDetails(id);
        } catch (_) {}
      }
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ListeningPartyScreen(room: room)),
      );
    } catch (e) {
      if (!context.mounted) return;
      final detail = e.toString().contains('404')
          ? 'Room no longer active'
          : 'Could not open room';
      _inviteSnack(context, detail, error: true);
    }
  }

  void _inviteSnack(BuildContext context, String text, {bool error = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: error
                ? const LinearGradient(
                    colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)])
                : AppColors.gradPurple,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Icon(error ? Icons.error_outline_rounded : Icons.check_rounded,
                size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ]),
        ),
      ),
    );
  }

  int? _roomIdFromInviteCode(String code) {
    final normalized = code.trim().toUpperCase();
    final match = RegExp(r'^MW-([0-9A-F]+)$').firstMatch(normalized);
    if (match == null) return null;
    return int.tryParse(match.group(1)!, radix: 16);
  }

  @override
  Widget build(BuildContext context) {
    final sentAt = msg['sent_at'] as String? ?? '';
    final timeStr = _formatChatTime(sentAt);
    final title = (msg['room_title'] ?? 'Live Room').toString();
    final description = (msg['room_description'] ?? '').toString();
    final role = (msg['invite_role'] ?? 'listener').toString();
    final bg = buildMediaUrl((msg['room_background_url'] ?? '').toString());
    final roleLabel = role.isEmpty
        ? 'Listener'
        : '${role[0].toUpperCase()}${role.substring(1).replaceAll('_', ' ')}';

    final bubble = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openRoom(context),
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.purpleLight.withOpacity(0.28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.purpleDark.withOpacity(0.26),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: bg.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: bg,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        decoration:
                            BoxDecoration(gradient: AppColors.gradPurple),
                      ),
                    )
                  : Container(
                      decoration:
                          BoxDecoration(gradient: AppColors.gradPurple)),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(bg.isNotEmpty ? 0.36 : 0.04),
                      AppColors.purpleDark.withOpacity(0.18),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.headphones_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Live Room invite',
                                  style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                              const SizedBox(height: 2),
                              Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white)),
                            ]),
                      ),
                    ]),
                    if (description.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.white.withOpacity(0.78))),
                    ],
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _inviteChip(roleLabel),
                      _inviteChip(
                          msg['is_public'] == true ? 'Public' : 'Private'),
                    ]),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('Tap to join →',
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.78))),
                    ),
                  ]),
            ),
          ],
        ),
      ),
    );

    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openRoom(context),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _ForwardedLabel(msg: msg, isMe: isMe),
          bubble,
          if (footer != null) ...[const SizedBox(height: 2), footer!],
          if (timeStr.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(timeStr,
                style:
                    GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
          ],
        ],
      ),
    );

    if (isMe) return Align(alignment: Alignment.centerRight, child: content);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _Avatar(initial: partnerInitial, imageUrl: partnerAvatarUrl),
      const SizedBox(width: 8),
      Flexible(child: content),
    ]);
  }

  Widget _inviteChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: GoogleFonts.outfit(
              fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}

// ─── Track Message ────────────────────────────────────────────────────────────

class _TrackMessage extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String partnerInitial;
  final String partnerAvatarUrl;
  final int? matchId;
  final int? chatId;
  final int? groupChatId;
  final bool useGroupChat;
  final bool useDirectThread;
  final VoidCallback onReacted;
  const _TrackMessage(
      {required this.msg,
      required this.isMe,
      required this.partnerInitial,
      required this.partnerAvatarUrl,
      required this.matchId,
      required this.chatId,
      required this.groupChatId,
      required this.useGroupChat,
      required this.useDirectThread,
      required this.onReacted});

  @override
  Widget build(BuildContext context) {
    final title = msg['track_title'] ?? 'Unknown track';
    final artist = msg['track_artist'] ?? '';
    final coverUrl = msg['track_cover_url'] as String?;
    final phrase = msg['phrase'] as String? ?? '';
    final phraseEmoji = msg['phrase_emoji'] as String? ?? '🎵';
    final note = msg['note'] as String? ?? '';
    final messageId = msg['message_id'] as String?;
    final sentAt = msg['sent_at'] as String? ?? '';
    final timeStr = _formatChatTime(sentAt);
    final rawReactions = msg['reactions'];
    final reactions =
        rawReactions is Map ? Map<String, dynamic>.from(rawReactions) : {};

    final bubble = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.purple.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phrase badge
          if (phrase.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.purple.withOpacity(0.15),
                  AppColors.pink.withOpacity(0.08),
                ]),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                    bottom:
                        BorderSide(color: AppColors.purple.withOpacity(0.15))),
              ),
              child: Row(children: [
                Text(phraseEmoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(phrase,
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppColors.text2,
                          height: 1.3)),
                ),
              ]),
            ),
          // Track info row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              // Cover art
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: AppColors.gradMixed,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.purpleDark.withOpacity(0.3),
                        blurRadius: 10)
                  ],
                ),
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Text('🎵',
                                    style: TextStyle(fontSize: 22)))))
                    : const Center(
                        child: Text('🎵', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text),
                          overflow: TextOverflow.ellipsis),
                      if (artist.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(artist,
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: AppColors.text2),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ]),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.play_circle_filled_rounded,
                  color: AppColors.purpleLight, size: 28),
            ]),
          ),
          // Reactions
          if (reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Wrap(
                spacing: 5,
                children: reactions.entries.map((e) {
                  final emoji = e.key;
                  final users = (e.value as List?) ?? [];
                  if (users.isEmpty) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: messageId != null
                        ? () async {
                            try {
                              if (useGroupChat) {
                                await ApiService().reactToGroupMessage(
                                    groupChatId!, messageId, emoji);
                              } else if (useDirectThread) {
                                await ApiService().reactToDirectMessage(
                                    chatId!, messageId, emoji);
                              } else {
                                await ApiService()
                                    .reactToMessage(matchId!, messageId, emoji);
                              }
                              onReacted();
                            } catch (_) {}
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: AppColors.purple.withOpacity(0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 3),
                        Text('${users.length}',
                            style: GoogleFonts.outfit(
                                fontSize: 11, color: AppColors.text2)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                note,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.text2,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );

    if (isMe) {
      return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Align(alignment: Alignment.centerRight, child: bubble),
        if (timeStr.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(timeStr,
              style: GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
        ],
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _Avatar(initial: partnerInitial, imageUrl: partnerAvatarUrl),
        const SizedBox(width: 8),
        Flexible(child: bubble),
      ]),
      if (timeStr.isNotEmpty) ...[
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 42),
          child: Text(timeStr,
              style: GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
        ),
      ],
    ]);
  }
}

class _AlbumMessage extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String partnerInitial;
  final String partnerAvatarUrl;
  final Widget? footer;

  const _AlbumMessage({
    required this.msg,
    required this.isMe,
    required this.partnerInitial,
    required this.partnerAvatarUrl,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final title = msg['album_title']?.toString() ?? 'Album';
    final artist = msg['album_artist']?.toString() ?? '';
    final coverUrl = msg['album_cover_url']?.toString() ?? '';
    final note = msg['note']?.toString() ?? '';
    final sentAt = msg['sent_at'] as String? ?? '';
    final timeStr = _formatChatTime(sentAt);

    final card = _AttachmentCard(
      icon: Icons.album_rounded,
      title: title,
      subtitle: artist.isNotEmpty ? artist : 'Album',
      coverUrl: coverUrl,
      note: note,
      accent: AppColors.blueLight,
    );

    return _MessageFrame(
      isMe: isMe,
      partnerInitial: partnerInitial,
      partnerAvatarUrl: partnerAvatarUrl,
      timeStr: timeStr,
      footer: footer,
      child: card,
    );
  }
}

class _PlaylistMessage extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String partnerInitial;
  final String partnerAvatarUrl;
  final Widget? footer;

  const _PlaylistMessage({
    required this.msg,
    required this.isMe,
    required this.partnerInitial,
    required this.partnerAvatarUrl,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final title = msg['playlist_title']?.toString() ?? 'Playlist';
    final coverUrl = msg['playlist_cover_url']?.toString() ?? '';
    final trackCount = msg['playlist_track_count'];
    final note = msg['note']?.toString() ?? '';
    final sentAt = msg['sent_at'] as String? ?? '';
    final timeStr = _formatChatTime(sentAt);

    final countText =
        trackCount is int && trackCount > 0 ? '$trackCount tracks' : 'Playlist';

    final card = _AttachmentCard(
      icon: Icons.queue_music_rounded,
      title: title,
      subtitle: countText,
      coverUrl: coverUrl,
      note: note,
      accent: AppColors.purpleLight,
    );

    return _MessageFrame(
      isMe: isMe,
      partnerInitial: partnerInitial,
      partnerAvatarUrl: partnerAvatarUrl,
      timeStr: timeStr,
      footer: footer,
      child: card,
    );
  }
}

class _ProfileMessage extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String partnerInitial;
  final String partnerAvatarUrl;

  const _ProfileMessage({
    required this.msg,
    required this.isMe,
    required this.partnerInitial,
    required this.partnerAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = msg['profile_display_name']?.toString() ?? 'User';
    final username = msg['profile_username']?.toString() ?? '';
    final avatarUrl = msg['profile_avatar_url']?.toString() ?? '';
    final profileUserId = (msg['profile_user_id'] as num?)?.toInt() ?? 0;
    final sentAt = msg['sent_at'] as String? ?? '';
    final timeStr = _formatChatTime(sentAt);

    final card = GestureDetector(
      onTap: () {
        if (profileUserId > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: profileUserId),
            ),
          );
        }
      },
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1a0533), Color(0xFF2d1060), Color(0xFF0d1a3d)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x33A855F7)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ClipOval(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7c3aed), Color(0xFFec4899)],
                    ),
                  ),
                  child: avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Center(
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : 'U',
                              style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'U',
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                    if (username.isNotEmpty)
                      Text(
                        '@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: const Color(0xB3C8B4FF)),
                      ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.graphic_eq_rounded,
                  size: 10, color: Colors.white38),
              const SizedBox(width: 4),
              Text('MoodWave',
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white38)),
            ]),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF7c3aed), Color(0xFFec4899)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Open Profile',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    return _MessageFrame(
      isMe: isMe,
      partnerInitial: partnerInitial,
      partnerAvatarUrl: partnerAvatarUrl,
      timeStr: timeStr,
      child: card,
    );
  }
}

class _ImageMessage extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String partnerInitial;
  final String partnerAvatarUrl;
  final Widget? footer;

  const _ImageMessage({
    required this.msg,
    required this.isMe,
    required this.partnerInitial,
    required this.partnerAvatarUrl,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final imageDataUrl = msg['image_data_url']?.toString() ?? '';
    final caption = msg['caption']?.toString() ?? '';
    final sentAt = msg['sent_at'] as String? ?? '';
    final timeStr = _formatChatTime(sentAt);

    final card = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 240,
            child: _SmartImage(
              imageUrl: imageDataUrl,
              fit: BoxFit.cover,
              error: Container(
                color: AppColors.surface,
                alignment: Alignment.center,
                child: const Icon(Icons.image_rounded,
                    color: Colors.white70, size: 28),
              ),
            ),
          ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Text(
                caption,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.text,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );

    return _MessageFrame(
      isMe: isMe,
      partnerInitial: partnerInitial,
      partnerAvatarUrl: partnerAvatarUrl,
      timeStr: timeStr,
      footer: footer,
      child: card,
    );
  }
}

class _MessageFrame extends StatelessWidget {
  final bool isMe;
  final String partnerInitial;
  final String partnerAvatarUrl;
  final String timeStr;
  final Widget? footer;
  final Widget child;

  const _MessageFrame({
    required this.isMe,
    required this.partnerInitial,
    required this.partnerAvatarUrl,
    required this.timeStr,
    this.footer,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (isMe) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(alignment: Alignment.centerRight, child: child),
          if (footer != null) ...[
            const SizedBox(height: 6),
            footer!,
          ],
          if (timeStr.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(timeStr,
                style:
                    GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Avatar(initial: partnerInitial, imageUrl: partnerAvatarUrl),
            const SizedBox(width: 8),
            Flexible(child: child),
          ],
        ),
        if (footer != null) ...[
          const SizedBox(height: 6),
          footer!,
        ],
        if (timeStr.isNotEmpty) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Text(timeStr,
                style:
                    GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
          ),
        ],
      ],
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String coverUrl;
  final String note;
  final Color accent;

  const _AttachmentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.note,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: AppColors.gradMixed,
              borderRadius: BorderRadius.circular(14),
            ),
            child: coverUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(icon, color: Colors.white70),
                    ),
                  )
                : Icon(icon, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: accent,
                  ),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    note,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.text2,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatNowPlayingBar extends StatelessWidget {
  const _ChatNowPlayingBar();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        final track = provider.track;
        if (track == null) return const SizedBox.shrink();

        final title =
            (track['title'] ?? track['trackName'] ?? 'Unknown').toString();
        final artist =
            (track['artist'] ?? track['artistName'] ?? '').toString();
        final coverUrl =
            (track['cover_url'] ?? track['artworkUrl100'])?.toString() ?? '';

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2B164B),
                  const Color(0xFF1C254F),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purpleDark.withOpacity(0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradMixed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: coverUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('🎵', style: TextStyle(fontSize: 18)),
                            ),
                          ),
                        )
                      : const Center(
                          child: Text('🎵', style: TextStyle(fontSize: 18)),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: provider.togglePlayPause,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryBtn,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      provider.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: provider.stop,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.glass,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.text3,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatSearchResult {
  final int index;
  final String text;
  final String type;
  final String time;

  const _ChatSearchResult({
    required this.index,
    required this.text,
    required this.type,
    required this.time,
  });
}

class _ChatSearchScreen extends StatefulWidget {
  final String partnerName;
  final List<_ChatSearchResult> results;
  final void Function(int index, String query) onJumpToMessage;
  final IconData Function(String type) typeIconBuilder;

  const _ChatSearchScreen({
    required this.partnerName,
    required this.results,
    required this.onJumpToMessage,
    required this.typeIconBuilder,
  });

  @override
  State<_ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<_ChatSearchScreen> {
  final _queryCtrl = TextEditingController();
  int _selectedIndex = 0;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<_ChatSearchResult> get _filteredResults {
    final query = _queryCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return widget.results;
    return widget.results
        .where((item) => item.text.toLowerCase().contains(query))
        .toList();
  }

  void _moveSelection(int delta) {
    final results = _filteredResults;
    if (results.isEmpty) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta) % results.length;
      if (_selectedIndex < 0) {
        _selectedIndex = results.length - 1;
      }
    });
  }

  String _snippet(String text, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return text.length > 90 ? '${text.substring(0, 90)}…' : text;
    }
    final lower = text.toLowerCase();
    final idx = lower.indexOf(normalized);
    if (idx < 0) {
      return text.length > 90 ? '${text.substring(0, 90)}…' : text;
    }
    final start = (idx - 28).clamp(0, text.length);
    final end = (idx + normalized.length + 48).clamp(0, text.length);
    final prefix = start > 0 ? '…' : '';
    final suffix = end < text.length ? '…' : '';
    return '$prefix${text.substring(start, end)}$suffix';
  }

  InlineSpan _buildHighlightedSpan(String text, String query,
      {required bool selected}) {
    final normalized = query.trim().toLowerCase();
    final baseStyle = GoogleFonts.outfit(
      fontSize: 14,
      color: AppColors.text,
      height: 1.4,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    if (normalized.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    final lower = text.toLowerCase();
    final matches = <int>[];
    var start = 0;
    while (start < lower.length) {
      final idx = lower.indexOf(normalized, start);
      if (idx < 0) break;
      matches.add(idx);
      start = idx + normalized.length;
    }
    if (matches.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final idx in matches) {
      if (idx > cursor) {
        children.add(TextSpan(text: text.substring(cursor, idx)));
      }
      children.add(
        TextSpan(
          text: text.substring(idx, idx + normalized.length),
          style: baseStyle.copyWith(
            color: AppColors.purpleLight,
            fontWeight: FontWeight.w800,
            backgroundColor: AppColors.purpleLight.withOpacity(0.15),
          ),
        ),
      );
      cursor = idx + normalized.length;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: baseStyle, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredResults;
    if (_selectedIndex >= results.length && results.isNotEmpty) {
      _selectedIndex = results.length - 1;
    }
    if (results.isEmpty) {
      _selectedIndex = 0;
    }
    final query = _queryCtrl.text.trim();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.glass,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.text,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: TextField(
                            controller: _queryCtrl,
                            autofocus: true,
                            onChanged: (_) =>
                                setState(() => _selectedIndex = 0),
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search in chat',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: AppColors.text3,
                              ),
                              suffixIcon: _queryCtrl.text.isEmpty
                                  ? null
                                  : GestureDetector(
                                      onTap: () => setState(() {
                                        _queryCtrl.clear();
                                        _selectedIndex = 0;
                                      }),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: AppColors.text3,
                                      ),
                                    ),
                              hintStyle: GoogleFonts.outfit(
                                fontSize: 15,
                                color: AppColors.text3,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          results.isEmpty
                              ? 'No matches'
                              : '${_selectedIndex + 1} of ${results.length}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _SearchNavButton(
                        icon: Icons.keyboard_arrow_up_rounded,
                        enabled: results.isNotEmpty,
                        onTap: () => _moveSelection(-1),
                      ),
                      const SizedBox(width: 8),
                      _SearchNavButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        enabled: results.isNotEmpty,
                        onTap: () => _moveSelection(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        query.isEmpty
                            ? 'Type a word to search through the chat'
                            : 'No matches for "$query"',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppColors.text3,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final item = results[i];
                        final selected = i == _selectedIndex;
                        return GestureDetector(
                          onTap: () =>
                              widget.onJumpToMessage(item.index, query),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.purple.withOpacity(0.14)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? AppColors.purpleLight.withOpacity(0.5)
                                    : AppColors.border,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color:
                                            AppColors.purple.withOpacity(0.14),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.gradMixed,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    widget.typeIconBuilder(item.type),
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        text: _buildHighlightedSpan(
                                          _snippet(item.text, query),
                                          query,
                                          selected: selected,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.time.isEmpty
                                            ? 'Open in chat'
                                            : 'Open in chat · ${item.time}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: AppColors.text3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _SearchNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: enabled ? AppColors.surface : AppColors.glass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.text : AppColors.text3,
          size: 22,
        ),
      ),
    );
  }
}

// ─── Group Members Sheet ──────────────────────────────────────────────────────

class _GroupMembersSheet extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final int ownerId;
  final int currentUserId;
  final bool amIOwner;
  final int groupChatId;
  final VoidCallback onMemberRemoved;
  final void Function(int) onOwnerTransferred;

  const _GroupMembersSheet({
    required this.members,
    required this.ownerId,
    required this.currentUserId,
    required this.amIOwner,
    required this.groupChatId,
    required this.onMemberRemoved,
    required this.onOwnerTransferred,
  });

  @override
  State<_GroupMembersSheet> createState() => _GroupMembersSheetState();
}

class _GroupMembersSheetState extends State<_GroupMembersSheet> {
  late List<Map<String, dynamic>> _members;

  @override
  void initState() {
    super.initState();
    _members = List<Map<String, dynamic>>.from(widget.members);
  }

  Future<void> _remove(Map<String, dynamic> member) async {
    final id = (member['id'] as num?)?.toInt() ?? 0;
    final name =
        (member['display_name'] ?? member['username'] ?? 'user').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove $name?',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, color: AppColors.text)),
        content: Text('They will be removed from the group.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove',
                style: GoogleFonts.outfit(color: const Color(0xFFef4444))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService().removeGroupChatMember(widget.groupChatId, id);
      setState(
          () => _members.removeWhere((m) => (m['id'] as num?)?.toInt() == id));
      widget.onMemberRemoved();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove member')));
    }
  }

  Future<void> _transferOwner(Map<String, dynamic> member) async {
    final id = (member['id'] as num?)?.toInt() ?? 0;
    final name =
        (member['display_name'] ?? member['username'] ?? 'user').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Transfer ownership to $name?',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, color: AppColors.text)),
        content: Text(
            'You will become a regular member. This cannot be undone without their approval.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppColors.text3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Transfer',
                style: GoogleFonts.outfit(color: AppColors.purpleLight)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService().transferGroupChatOwner(widget.groupChatId, id);
      setState(() {
        for (final m in _members) {
          if ((m['id'] as num?)?.toInt() == id) {
            m['role'] = 'owner';
          } else if ((m['id'] as num?)?.toInt() == widget.currentUserId) {
            m['role'] = 'member';
          }
        }
      });
      widget.onOwnerTransferred(id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not transfer ownership')));
    }
  }

  Future<void> _makeAdmin(Map<String, dynamic> member) async {
    final id = (member['id'] as num?)?.toInt() ?? 0;
    final name =
        (member['display_name'] ?? member['username'] ?? 'user').toString();
    try {
      await ApiService().makeGroupChatAdmin(widget.groupChatId, id);
      setState(() {
        for (final m in _members) {
          if ((m['id'] as num?)?.toInt() == id) m['role'] = 'admin';
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not make $name an admin')));
    }
  }

  Future<void> _revokeAdmin(Map<String, dynamic> member) async {
    final id = (member['id'] as num?)?.toInt() ?? 0;
    try {
      await ApiService().revokeGroupChatAdmin(widget.groupChatId, id);
      setState(() {
        for (final m in _members) {
          if ((m['id'] as num?)?.toInt() == id) m['role'] = 'member';
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not revoke admin')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Text(
                  'Members',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_members.length}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.purpleLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _members.length,
              itemBuilder: (_, i) {
                final m = _members[i];
                final uid = (m['id'] as num?)?.toInt() ?? 0;
                final name =
                    (m['display_name'] ?? m['username'] ?? 'User').toString();
                final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                final avatarUrl = (m['avatar_url'] ?? '').toString();
                final isOwner = m['role'] == 'owner';
                final isAdminRole = m['role'] == 'admin';
                final isMe = uid == widget.currentUserId;
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  onTap: !isMe
                      ? () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                userId: uid,
                                initialUser: m,
                              ),
                            ),
                          );
                        }
                      : null,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.gradMixed,
                    ),
                    child: avatarUrl.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Center(
                                child: Text(initial,
                                    style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(initial,
                                style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          isMe ? '$name (you)' : name,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (isOwner || isAdminRole) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.purpleDark.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            isOwner ? 'owner' : 'admin',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isOwner
                                  ? AppColors.pink
                                  : AppColors.purpleLight,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: (widget.amIOwner && !isMe && !isOwner)
                      ? PopupMenuButton<String>(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          icon: const Icon(Icons.more_vert_rounded,
                              size: 18, color: AppColors.text3),
                          onSelected: (v) {
                            if (v == 'remove') _remove(m);
                            if (v == 'make_admin') _makeAdmin(m);
                            if (v == 'revoke_admin') _revokeAdmin(m);
                            if (v == 'transfer') _transferOwner(m);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'remove',
                              child: Row(children: [
                                const Icon(Icons.person_remove_rounded,
                                    size: 16, color: Color(0xFFef4444)),
                                const SizedBox(width: 8),
                                Text('Remove',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: const Color(0xFFef4444))),
                              ]),
                            ),
                            if (!isAdminRole)
                              PopupMenuItem(
                                value: 'make_admin',
                                child: Row(children: [
                                  const Icon(Icons.shield_rounded,
                                      size: 16, color: AppColors.purpleLight),
                                  const SizedBox(width: 8),
                                  Text('Make admin',
                                      style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: AppColors.purpleLight)),
                                ]),
                              )
                            else
                              PopupMenuItem(
                                value: 'revoke_admin',
                                child: Row(children: [
                                  const Icon(Icons.shield_outlined,
                                      size: 16, color: AppColors.text2),
                                  const SizedBox(width: 8),
                                  Text('Revoke admin',
                                      style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: AppColors.text2)),
                                ]),
                              ),
                            PopupMenuItem(
                              value: 'transfer',
                              child: Row(children: [
                                const Icon(Icons.manage_accounts_rounded,
                                    size: 16, color: AppColors.text3),
                                const SizedBox(width: 8),
                                Text('Transfer ownership',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13, color: AppColors.text3)),
                              ]),
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Track Picker Sheet ───────────────────────────────────────────────────────

class _TrackPickerSheet extends StatefulWidget {
  final void Function(
    Map<String, dynamic> track,
    String? phrase,
    String? phraseEmoji,
    String? note,
  ) onSend;
  const _TrackPickerSheet({required this.onSend});

  @override
  State<_TrackPickerSheet> createState() => _TrackPickerSheetState();
}

class _TrackPickerSheetState extends State<_TrackPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  List<Map<String, dynamic>> _tracks = [];
  bool _loading = true;
  Map<String, dynamic>? _selected;
  String? _selectedPhrase;
  String? _selectedPhraseEmoji;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final raw = await ApiService().getRecentlyPlayed(limit: 20);
      if (!mounted) return;
      setState(() {
        _tracks = raw.whereType<Map>().map((e) {
          final m = Map<String, dynamic>.from(e);
          final track = m['track'] as Map? ?? m;
          return Map<String, dynamic>.from(track);
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      _loadRecent();
      return;
    }
    setState(() => _loading = true);
    try {
      final raw = await ApiService().searchTracksWithFallback(q, limit: 15);
      if (!mounted) return;
      setState(() {
        _tracks = raw;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(children: [
        // Handle
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(100)),
        ),
        const SizedBox(height: 14),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Icon(Icons.music_note_rounded,
                size: 20, color: AppColors.purpleLight),
            const SizedBox(width: 8),
            Text('Send a Track',
                style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
          ]),
        ),
        const SizedBox(height: 12),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
              onChanged: (v) => _search(v),
              decoration: InputDecoration(
                hintText: 'Search tracks...',
                hintStyle:
                    GoogleFonts.outfit(fontSize: 14, color: AppColors.text3),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: AppColors.text3),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Selected phrase picker
        if (_selected != null) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.purple.withOpacity(0.12),
                AppColors.pink.withOpacity(0.06),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.purple.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose a vibe phrase (optional)',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.text3)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _kPhrases.map((pair) {
                    final (phrase, emoji) = pair;
                    final active = _selectedPhrase == phrase;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedPhrase = active ? null : phrase;
                        _selectedPhraseEmoji = active ? null : emoji;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: active ? AppColors.gradPurple : null,
                          color: active ? null : AppColors.glass,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color: active
                                  ? Colors.transparent
                                  : AppColors.border),
                        ),
                        child: Text('$emoji $phrase',
                            style: GoogleFonts.outfit(
                                fontSize: 12,
                                color:
                                    active ? Colors.white : AppColors.text2)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.glass,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    maxLength: 240,
                    style:
                        GoogleFonts.outfit(fontSize: 13, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Add a note (optional)',
                      hintStyle: GoogleFonts.outfit(
                          fontSize: 13, color: AppColors.text3),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _sending
                      ? null
                      : () {
                          widget.onSend(
                            _selected!,
                            _selectedPhrase,
                            _selectedPhraseEmoji,
                            _noteCtrl.text.trim().isEmpty
                                ? null
                                : _noteCtrl.text.trim(),
                          );
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryBtn,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.purple.withOpacity(0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    child: Text('Send Track',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        // Track list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.purpleLight))
              : _tracks.isEmpty
                  ? Center(
                      child: Text('No tracks found',
                          style: GoogleFonts.outfit(color: AppColors.text3)))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _tracks.length,
                      itemBuilder: (_, i) {
                        final t = _tracks[i];
                        final title = t['title']?.toString() ?? 'Unknown';
                        final artist = t['artist']?.toString() ?? '';
                        final cover = t['cover_url']?.toString();
                        final isSelected = _selected == t;

                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selected = isSelected ? null : t),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.purple.withOpacity(0.12)
                                  : AppColors.glass,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: isSelected
                                      ? AppColors.purple.withOpacity(0.35)
                                      : AppColors.border),
                            ),
                            child: Row(children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: AppColors.gradMixed,
                                ),
                                child: cover != null && cover.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(cover,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Center(
                                                    child: Text('🎵',
                                                        style: TextStyle(
                                                            fontSize: 18)))))
                                    : const Center(
                                        child: Text('🎵',
                                            style: TextStyle(fontSize: 18))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(title,
                                          style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.text),
                                          overflow: TextOverflow.ellipsis),
                                      if (artist.isNotEmpty)
                                        Text(artist,
                                            style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                color: AppColors.text2),
                                            overflow: TextOverflow.ellipsis),
                                    ]),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.purpleLight, size: 22),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class _AlbumPickerSheet extends StatefulWidget {
  final void Function(Map<String, dynamic> album, String? note) onSend;
  const _AlbumPickerSheet({required this.onSend});

  @override
  State<_AlbumPickerSheet> createState() => _AlbumPickerSheetState();
}

class _AlbumPickerSheetState extends State<_AlbumPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  List<Map<String, dynamic>> _albums = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _albums = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final raw = await ApiService().searchAlbums(q.trim(), limit: 16);
      if (!mounted) return;
      setState(() {
        _albums = raw;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _MediaPickerShell(
      title: 'Send an Album',
      child: Column(
        children: [
          _SearchInput(
            controller: _searchCtrl,
            hint: 'Search albums...',
            onChanged: _search,
          ),
          if (_selected != null) ...[
            const SizedBox(height: 12),
            _NoteAndSendCard(
              controller: _noteCtrl,
              onSend: () => widget.onSend(
                _selected!,
                _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.purpleLight))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _albums.length,
                    itemBuilder: (_, i) {
                      final album = _albums[i];
                      final title = album['title']?.toString() ?? 'Album';
                      final artist = album['artist']?.toString() ?? '';
                      final cover = album['cover_xl']?.toString() ?? '';
                      final selected = identical(_selected, album);
                      return _SelectableMediaRow(
                        title: title,
                        subtitle: artist.isNotEmpty ? artist : 'Album',
                        imageUrl: cover,
                        selected: selected,
                        onTap: () =>
                            setState(() => _selected = selected ? null : album),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistPickerSheet extends StatefulWidget {
  final void Function(Map<String, dynamic> playlist, String? note) onSend;
  const _PlaylistPickerSheet({required this.onSend});

  @override
  State<_PlaylistPickerSheet> createState() => _PlaylistPickerSheetState();
}

class _PlaylistPickerSheetState extends State<_PlaylistPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    try {
      final raw = await ApiService().getPlaylists();
      if (!mounted) return;
      setState(() {
        _items = raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      _loadMine();
      return;
    }
    setState(() => _loading = true);
    try {
      final raw = await ApiService().searchPlaylists(q.trim(), limit: 20);
      if (!mounted) return;
      setState(() {
        _items = raw;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _MediaPickerShell(
      title: 'Send a Playlist',
      child: Column(
        children: [
          _SearchInput(
            controller: _searchCtrl,
            hint: 'Search playlists...',
            onChanged: _search,
          ),
          if (_selected != null) ...[
            const SizedBox(height: 12),
            _NoteAndSendCard(
              controller: _noteCtrl,
              onSend: () => widget.onSend(
                _selected!,
                _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.purpleLight))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final playlist = _items[i];
                      final title = playlist['title']?.toString() ?? 'Playlist';
                      final count = playlist['track_count'];
                      final cover = playlist['cover_url']?.toString() ?? '';
                      final selected = identical(_selected, playlist);
                      return _SelectableMediaRow(
                        title: title,
                        subtitle: count is int ? '$count tracks' : 'Playlist',
                        imageUrl: cover,
                        selected: selected,
                        onTap: () => setState(
                            () => _selected = selected ? null : playlist),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentOptionsSheet extends StatelessWidget {
  final VoidCallback onTrack;
  final VoidCallback onAlbum;
  final VoidCallback onPlaylist;
  final VoidCallback onImage;

  const _AttachmentOptionsSheet({
    required this.onTrack,
    required this.onAlbum,
    required this.onPlaylist,
    required this.onImage,
  });

  @override
  Widget build(BuildContext context) {
    Widget option(
        IconData icon, String label, Color color, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.surface.withOpacity(0.98),
                AppColors.surface2.withOpacity(0.88),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label == 'Send a photo'
                          ? 'Share a memory from your gallery'
                          : 'Drop it into the conversation instantly',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.text3,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Share in chat',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Text(
                'Choose what to send',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.text3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          option(Icons.music_note_rounded, 'Share a track',
              AppColors.purpleLight, onTrack),
          const SizedBox(height: 10),
          option(Icons.album_rounded, 'Share an album', AppColors.blueLight,
              onAlbum),
          const SizedBox(height: 10),
          option(Icons.queue_music_rounded, 'Share a playlist',
              AppColors.pinkLight, onPlaylist),
          const SizedBox(height: 10),
          option(Icons.image_rounded, 'Send a photo', AppColors.green, onImage),
        ],
      ),
    );
  }
}

class _ImagePreviewSheet extends StatelessWidget {
  final Uint8List bytes;
  final TextEditingController controller;

  const _ImagePreviewSheet({
    required this.bytes,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send a Photo',
              style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: controller,
              maxLines: 2,
              maxLength: 240,
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Add a caption (optional)',
                hintStyle:
                    GoogleFonts.outfit(fontSize: 13, color: AppColors.text3),
                border: InputBorder.none,
                counterText: '',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.primaryBtn,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Send Photo',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPickerShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _MediaPickerShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(100)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.send_rounded,
                    size: 18, color: AppColors.purpleLight),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchInput({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(fontSize: 14, color: AppColors.text3),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: AppColors.text3),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

class _NoteAndSendCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _NoteAndSendCard({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: 2,
            maxLength: 240,
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text),
            decoration: InputDecoration(
              hintText: 'Add your note (optional)',
              hintStyle:
                  GoogleFonts.outfit(fontSize: 13, color: AppColors.text3),
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: AppColors.primaryBtn,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Send',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableMediaRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableMediaRow({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.purple.withOpacity(0.12) : AppColors.glass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.purple.withOpacity(0.32)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: AppColors.gradMixed,
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white70),
                      ),
                    )
                  : const Icon(Icons.music_note_rounded, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.text2,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.purpleLight, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Avatar widget ────────────────────────────────────────────────────────────

class _ForwardTarget {
  final String kind;
  final int id;

  const _ForwardTarget(this.kind, this.id);

  static _ForwardTarget? fromChat(Map<String, dynamic> chat) {
    final groupId = (chat['group_chat_id'] as num?)?.toInt();
    if (groupId != null) return _ForwardTarget('group', groupId);
    final chatId = (chat['chat_id'] as num?)?.toInt();
    if (chatId != null) return _ForwardTarget('thread', chatId);
    final matchId = (chat['match_id'] as num?)?.toInt();
    if (matchId != null) return _ForwardTarget('match', matchId);
    return null;
  }
}

class _Avatar extends StatelessWidget {
  final String initial;
  final String imageUrl;
  final double size;
  final double fontSize;
  final double borderWidth;

  const _Avatar({
    required this.initial,
    this.imageUrl = '',
    this.size = 32,
    this.fontSize = 12,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: imageUrl.isNotEmpty ? Colors.transparent : null,
        gradient: imageUrl.isNotEmpty ? null : AppColors.gradMixed,
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(
                color: Colors.white.withOpacity(0.12),
                width: borderWidth,
              )
            : null,
      ),
      child: imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              imageBuilder: (_, imageProvider) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => _AvatarFallback(
                initial: initial,
                fontSize: fontSize,
              ),
            )
          : _AvatarFallback(
              initial: initial,
              fontSize: fontSize,
            ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initial;
  final double fontSize;

  const _AvatarFallback({
    required this.initial,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.outfit(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── Shared Content Screen ────────────────────────────────────────────────────

class _SharedContentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  final String partnerName;
  final int partnerId;
  final int currentUserId;
  final void Function(int index)? onJumpToMessage;

  const _SharedContentScreen({
    required this.messages,
    required this.partnerName,
    required this.partnerId,
    required this.currentUserId,
    this.onJumpToMessage,
  });

  @override
  State<_SharedContentScreen> createState() => _SharedContentScreenState();
}

class _SharedContentScreenState extends State<_SharedContentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _byType(String type) => widget.messages
      .where((m) => m['type']?.toString() == type)
      .toList()
      .reversed
      .toList();

  List<Map<String, dynamic>> get _images => _byType('image');

  List<Map<String, dynamic>> get _media {
    final tracks = _byType('track');
    final albums = _byType('album');
    final playlists = _byType('playlist');
    final all = [...tracks, ...albums, ...playlists];
    all.sort((a, b) {
      final ta = a['sent_at']?.toString() ?? '';
      final tb = b['sent_at']?.toString() ?? '';
      return tb.compareTo(ta);
    });
    return all;
  }

  List<Map<String, dynamic>> get _links {
    final regex = RegExp(r'https?://\S+');
    return widget.messages
        .where((m) => m['type']?.toString() == 'text')
        .where((m) {
          final text = m['text']?.toString() ?? '';
          return regex.hasMatch(text);
        })
        .map((m) {
          final text = m['text']?.toString() ?? '';
          final url = regex.firstMatch(text)?.group(0) ?? '';
          return {...m, '_link_url': url};
        })
        .toList()
        .reversed
        .toList();
  }

  void _jumpToMsg(Map<String, dynamic> m) {
    if (widget.onJumpToMessage == null) return;
    final idx = widget.messages.indexOf(m);
    if (idx >= 0) {
      Navigator.of(context).pop();
      widget.onJumpToMessage!(idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shared',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            Text(
              'with ${widget.partnerName}',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.text3,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.purpleLight,
          labelColor: AppColors.purpleLight,
          unselectedLabelColor: AppColors.text3,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'Music'),
            Tab(text: 'Photos'),
            Tab(text: 'Links'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _MusicContentTab(items: _media, onJump: _jumpToMsg),
          _PhotoGridTab(images: _images, onJump: _jumpToMsg),
          _LinksTab(links: _links, onJump: _jumpToMsg),
          _SharedGroupsTab(
            currentUserId: widget.currentUserId,
            partnerId: widget.partnerId,
          ),
        ],
      ),
    );
  }
}

class _MusicContentTab extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic>)? onJump;
  const _MusicContentTab({required this.items, this.onJump});

  @override
  State<_MusicContentTab> createState() => _MusicContentTabState();
}

class _MusicContentTabState extends State<_MusicContentTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items.where((m) {
      final type = m['type']?.toString() ?? '';
      final title = (type == 'album'
                  ? m['album_title']
                  : type == 'playlist'
                      ? m['playlist_title']
                      : m['track_title'])
              ?.toString()
              .toLowerCase() ??
          '';
      final artist = (type == 'album'
                  ? m['album_artist']
                  : type == 'track'
                      ? m['track_artist']
                      : null)
              ?.toString()
              .toLowerCase() ??
          '';
      final note = (m['note'] ?? '').toString().toLowerCase();
      return title.contains(q) || artist.contains(q) || note.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Search music, albums, playlists...',
                hintStyle:
                    GoogleFonts.outfit(fontSize: 14, color: AppColors.text3),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.text3, size: 18),
                suffixIcon: _query.isEmpty
                    ? null
                    : GestureDetector(
                        onTap: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                        }),
                        child: const Icon(Icons.close_rounded,
                            color: AppColors.text3, size: 18),
                      ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? _SharedEmptyState(
                  icon: Icons.music_note_rounded,
                  label: _query.isEmpty
                      ? 'No media shared yet'
                      : 'No results for "$_query"',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final m = items[i];
                    final type = m['type']?.toString() ?? 'track';
                    final time = _formatChatTime(m['sent_at']?.toString());
                    final note = (m['note'] ?? '').toString().trim();

                    if (type == 'album') {
                      final title = (m['album_title'] ?? 'Album').toString();
                      final artist = (m['album_artist'] ?? '').toString();
                      final coverUrl = (m['album_cover_url'] ?? '').toString();
                      final albumId =
                          int.tryParse((m['album_id'] ?? '').toString());
                      return _SharedCard(
                        icon: Icons.album_rounded,
                        title: title,
                        subtitle: artist,
                        tertiary: note.isNotEmpty ? note : null,
                        imageUrl: coverUrl,
                        time: time,
                        badge: 'Album',
                        onJump: widget.onJump != null
                            ? () => widget.onJump!(m)
                            : null,
                        onTap: albumId == null
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        AlbumScreen(albumId: albumId))),
                      );
                    }

                    if (type == 'playlist') {
                      final title =
                          (m['playlist_title'] ?? 'Playlist').toString();
                      final coverUrl =
                          (m['playlist_cover_url'] ?? '').toString();
                      final playlistId = (m['playlist_id'] as num?)?.toInt();
                      return _SharedCard(
                        icon: Icons.queue_music_rounded,
                        title: title,
                        subtitle: 'Playlist',
                        tertiary: note.isNotEmpty ? note : null,
                        imageUrl: coverUrl,
                        time: time,
                        badge: 'Playlist',
                        onJump: widget.onJump != null
                            ? () => widget.onJump!(m)
                            : null,
                        onTap: playlistId == null
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => PlaylistScreen(
                                        playlistId: playlistId))),
                      );
                    }

                    // track
                    final title = (m['track_title'] ?? 'Unknown').toString();
                    final artist = (m['track_artist'] ?? '').toString();
                    final coverUrl = (m['track_cover_url'] ?? '').toString();
                    return _SharedCard(
                      icon: Icons.music_note_rounded,
                      title: title,
                      subtitle: artist,
                      tertiary: note.isNotEmpty ? note : null,
                      imageUrl: coverUrl,
                      time: time,
                      badge: 'Track',
                      onJump: widget.onJump != null
                          ? () => widget.onJump!(m)
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerScreen(
                            track: {
                              'title': title,
                              'artist': artist,
                              'cover_url': coverUrl,
                              'spotify_id':
                                  (m['spotify_track_id'] ?? '').toString(),
                              'preview_url':
                                  (m['track_preview_url'] ?? '').toString(),
                              if (note.isNotEmpty) 'queue_context': note,
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SharedGroupsTab extends StatefulWidget {
  final int currentUserId;
  final int partnerId;

  const _SharedGroupsTab({
    required this.currentUserId,
    required this.partnerId,
  });

  @override
  State<_SharedGroupsTab> createState() => _SharedGroupsTabState();
}

class _SharedGroupsTabState extends State<_SharedGroupsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _rooms = [];

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final raw = await ApiService().getActiveRooms(limit: 100);
      final rooms = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((room) {
        final ids = ((room['participant_user_ids'] as List?) ?? const [])
            .map((id) => (id as num?)?.toInt())
            .whereType<int>()
            .toSet();
        return ids.contains(widget.currentUserId) &&
            ids.contains(widget.partnerId);
      }).toList();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.purpleLight,
          strokeWidth: 2,
        ),
      );
    }
    if (_rooms.isEmpty) {
      return const _SharedEmptyState(
        icon: Icons.groups_rounded,
        label: 'No shared groups yet',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: _rooms.length,
      itemBuilder: (_, i) {
        final room = _rooms[i];
        final count = (room['participant_count'] as num?)?.toInt() ?? 0;
        final active = room['is_active'] != false;
        return _SharedCard(
          icon: Icons.groups_rounded,
          title: (room['name'] ?? 'Live Room').toString(),
          subtitle: '$count participant${count == 1 ? '' : 's'}',
          tertiary: active ? 'Active now' : 'Inactive',
          imageUrl: (room['host'] as Map?)?['avatar_url']?.toString() ?? '',
          time: '',
          badge: active ? 'Active' : 'Room',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ListeningPartyScreen(room: room),
            ),
          ),
        );
      },
    );
  }
}

Uint8List? _tryDecodeDataImage(String imageUrl) {
  if (!imageUrl.startsWith('data:image')) return null;
  final commaIndex = imageUrl.indexOf(',');
  if (commaIndex < 0 || commaIndex + 1 >= imageUrl.length) return null;
  try {
    return base64Decode(imageUrl.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}

class _SmartImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? error;

  const _SmartImage({
    required this.imageUrl,
    required this.fit,
    this.placeholder,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = _tryDecodeDataImage(imageUrl);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => error ?? const SizedBox.shrink(),
      );
    }
    if (imageUrl.isEmpty) {
      return error ?? const SizedBox.shrink();
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      placeholder: placeholder == null ? null : (_, __) => placeholder!,
      errorWidget: (_, __, ___) => error ?? const SizedBox.shrink(),
    );
  }
}

class _SharedCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? tertiary;
  final String imageUrl;
  final String time;
  final String badge;
  final VoidCallback? onTap;
  final VoidCallback? onJump;

  const _SharedCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tertiary,
    required this.imageUrl,
    required this.time,
    required this.badge,
    this.onTap,
    this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onJump,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface.withOpacity(0.98),
              AppColors.surface2.withOpacity(0.86),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                borderRadius: BorderRadius.circular(16),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _SmartImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        error: Icon(icon, color: Colors.white70),
                      ),
                    )
                  : Icon(icon, color: Colors.white70, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.purpleLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.text2,
                      ),
                    ),
                  ],
                  if (tertiary != null && tertiary!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      tertiary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.text3,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      time,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: AppColors.text3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGridTab extends StatelessWidget {
  final List<Map<String, dynamic>> images;
  final void Function(Map<String, dynamic>)? onJump;
  const _PhotoGridTab({required this.images, this.onJump});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return _SharedEmptyState(
        icon: Icons.image_rounded,
        label: 'No images shared yet',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (_, i) {
        final url = (images[i]['image_url'] ??
                images[i]['image_data_url'] ??
                images[i]['url'] ??
                '')
            .toString();
        if (url.isEmpty) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _SharedImageViewerScreen(
                images: images,
                initialIndex: i,
              ),
            ),
          ),
          onLongPress: onJump != null ? () => onJump!(images[i]) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _SmartImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: Container(color: AppColors.surface),
                    error: Container(
                      color: AppColors.surface,
                      child: const Icon(Icons.broken_image_rounded,
                          color: AppColors.text3),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xAA000000)],
                      ),
                    ),
                    child: Text(
                      _formatChatTime(images[i]['sent_at']?.toString()),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LinksTab extends StatelessWidget {
  final List<Map<String, dynamic>> links;
  final void Function(Map<String, dynamic>)? onJump;
  const _LinksTab({required this.links, this.onJump});

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return _SharedEmptyState(
        icon: Icons.link_rounded,
        label: 'No links shared yet',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: links.length,
      itemBuilder: (_, i) {
        final m = links[i];
        final url = (m['_link_url'] ?? '').toString();
        final text = (m['text'] ?? '').toString();
        final time = _formatChatTime(m['sent_at']?.toString());
        return _SharedCard(
          icon: Icons.link_rounded,
          title: url,
          subtitle: text.replaceAll(url, '').trim(),
          imageUrl: '',
          time: time,
          badge: 'Link',
          onJump: onJump != null ? () => onJump!(m) : null,
        );
      },
    );
  }
}

class _SharedEmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SharedEmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: AppColors.gradMixed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withOpacity(0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: 28, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Open your conversation and send something beautiful here',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedImageViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;
  final String? title;

  const _SharedImageViewerScreen({
    required this.images,
    required this.initialIndex,
    this.title,
  });

  @override
  State<_SharedImageViewerScreen> createState() =>
      _SharedImageViewerScreenState();
}

class _SharedImageViewerScreenState extends State<_SharedImageViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _imageUrl(Map<String, dynamic> image) {
    return (image['image_url'] ?? image['image_data_url'] ?? image['url'] ?? '')
        .toString();
  }

  String _caption(Map<String, dynamic> image) {
    return (image['caption'] ?? image['title'] ?? '').toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.images[_currentIndex];
    final caption = _caption(current);
    final sentAt = _formatChatTime(current['sent_at']?.toString());

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (_, i) {
              final url = _imageUrl(widget.images[i]);
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: _SmartImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    error: const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white70,
                      size: 40,
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.42),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  if (widget.title != null &&
                      widget.title!.trim().isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.42),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.images.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption.isNotEmpty || sentAt.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.42),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (caption.isNotEmpty)
                          Text(
                            caption,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.white,
                              height: 1.35,
                            ),
                          ),
                        if (caption.isNotEmpty && sentAt.isNotEmpty)
                          const SizedBox(height: 6),
                        if (sentAt.isNotEmpty)
                          Text(
                            sentAt,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (widget.images.length > 1)
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final url = _imageUrl(widget.images[i]);
                        final selected = i == _currentIndex;
                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? Colors.white : Colors.white24,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _SmartImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              error: Container(
                                color: Colors.white10,
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
