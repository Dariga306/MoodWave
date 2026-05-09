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
import 'player_screen.dart';
import 'playlist_screen.dart';
import 'user_profile_screen.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

const _kPhrases = [
  ('Слушай это прямо сейчас', '🎵'),
  ('Напомнило о тебе', '💭'),
  ('Это точно про нас', '✨'),
  ('Для такой погоды', '🌧️'),
  ('Ты обязана это услышать', '🔥'),
  ('Почему это так больно', '😭'),
];

const _kReactions = ['❤️', '🔥', '😭', '🎯', '⚡', '💀', '🧐'];

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
  final String partnerName;
  final int partnerId;
  final String? partnerAvatarUrl;

  const ChatScreen({
    super.key,
    this.matchId,
    this.chatId,
    required this.partnerName,
    required this.partnerId,
    this.partnerAvatarUrl,
  }) : assert(matchId != null || chatId != null);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _mutedChatsKey = 'muted_chat_threads_v1';
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<GlobalKey> _messageKeys = [];
  List<dynamic> _messages = [];
  bool _sending = false;
  Timer? _pollTimer;
  int _lastCount = 0;
  bool _chatMuted = false;

  bool get _usesDirectThread => widget.matchId == null && widget.chatId != null;
  String get _conversationStorageKey =>
      _usesDirectThread ? 'thread:${widget.chatId}' : 'match:${widget.matchId}';

  @override
  void initState() {
    super.initState();
    _loadMuteState();
    _loadMessages();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
    try {
      final msgs = _usesDirectThread
          ? await ApiService().getDirectChatMessages(widget.chatId!)
          : await ApiService().getChatMessages(widget.matchId!);
      if (!mounted) return;
      final needsScroll = msgs.length != _lastCount;
      setState(() {
        _messages = msgs;
        _messageKeys = List<GlobalKey>.generate(
          msgs.length,
          (_) => GlobalKey(),
          growable: false,
        );
        _lastCount = msgs.length;
      });
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
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    HapticFeedback.lightImpact();
    setState(() => _sending = true);
    _textCtrl.clear();
    try {
      if (_usesDirectThread) {
        await ApiService().sendDirectTextMessage(widget.chatId!, text);
      } else {
        await ApiService().sendTextMessage(widget.matchId!, text);
      }
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;
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
    if (_usesDirectThread) {
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
            if (_usesDirectThread) {
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
            if (_usesDirectThread) {
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
      if (_usesDirectThread) {
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

  void _openConversationMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuTile(
              icon: Icons.group_add_rounded,
              label: 'Create listening group',
              onTap: () {
                Navigator.pop(context);
                _createListeningGroup();
              },
            ),
            _menuTile(
              icon: Icons.folder_shared_rounded,
              label: 'Shared',
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
              label: _chatMuted ? 'Unmute notifications' : 'Mute notifications',
              onTap: () {
                Navigator.pop(context);
                _toggleMuteConversation();
              },
            ),
            _menuTile(
              icon: Icons.graphic_eq_rounded,
              label: 'Browse live groups',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BrowseRoomsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createListeningGroup() async {
    try {
      final room = await ApiService().createListeningRoom(
        name: '${widget.partnerName} Listening Group',
        isPublic: false,
        maxGuests: 8,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ListeningPartyScreen(room: room),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSendError(e, fallback: 'Could not create listening group');
    }
  }

  void _openSharedContent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SharedContentScreen(
          messages: _messages
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList(),
          partnerName: widget.partnerName,
        ),
      ),
    );
  }

  void _openSearchInChat() {
    final candidates = _messages
        .asMap()
        .entries
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
          onJumpToMessage: (index) {
            Navigator.of(context).pop();
            _jumpToMessage(index);
          },
          typeIconBuilder: _messageTypeIcon,
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

  void _jumpToMessage(int index) {
    if (index < 0 || index >= _messageKeys.length) return;
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
    final initial = widget.partnerName.isNotEmpty
        ? widget.partnerName[0].toUpperCase()
        : 'U';
    final partnerAvatarUrl = widget.partnerAvatarUrl ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        _buildHeader(initial, partnerAvatarUrl),
        const _ChatNowPlayingBar(),
        Container(height: 1, color: AppColors.border),
        Expanded(
          child: _messages.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final msg = _messages[i] as Map<String, dynamic>;
                    final isMe = msg['sender_id'] == myId;
                    final type = msg['type'] ?? 'text';
                    return Padding(
                      key: i < _messageKeys.length ? _messageKeys[i] : null,
                      padding: const EdgeInsets.only(bottom: 10),
                      child: switch (type) {
                        'track' => _TrackMessage(
                            msg: msg,
                            isMe: isMe,
                            partnerInitial: initial,
                            partnerAvatarUrl: partnerAvatarUrl,
                            matchId: widget.matchId,
                            chatId: widget.chatId,
                            useDirectThread: _usesDirectThread,
                            onReacted: _loadMessages,
                          ),
                        'album' => _AlbumMessage(
                            msg: msg,
                            isMe: isMe,
                            partnerInitial: initial,
                            partnerAvatarUrl: partnerAvatarUrl,
                          ),
                        'playlist' => _PlaylistMessage(
                            msg: msg,
                            isMe: isMe,
                            partnerInitial: initial,
                            partnerAvatarUrl: partnerAvatarUrl,
                          ),
                        'image' => _ImageMessage(
                            msg: msg,
                            isMe: isMe,
                            partnerInitial: initial,
                            partnerAvatarUrl: partnerAvatarUrl,
                          ),
                        _ => _TextMessage(
                            msg: msg,
                            isMe: isMe,
                            partnerInitial: initial,
                            partnerAvatarUrl: partnerAvatarUrl,
                          ),
                      },
                    );
                  },
                ),
        ),
        _buildComposer(),
      ]),
    );
  }

  Widget _buildHeader(String initial, String partnerAvatarUrl) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: AppColors.glass,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border)),
                child: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.text, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _openPartnerProfile,
              child: _Avatar(
                initial: initial,
                imageUrl: partnerAvatarUrl,
                size: 44,
                fontSize: 17,
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
                      Text(widget.partnerName,
                          style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text)),
                      Row(children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: AppColors.purpleLight,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text('Music match',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: AppColors.purpleLight)),
                      ]),
                    ]),
              ),
            ),
            GestureDetector(
              onTap: _openConversationMenu,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(12),
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

class _TextMessage extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String partnerInitial;
  final String partnerAvatarUrl;
  const _TextMessage(
      {required this.msg,
      required this.isMe,
      required this.partnerInitial,
      required this.partnerAvatarUrl});

  @override
  Widget build(BuildContext context) {
    final text = msg['text'] ?? '';
    final sentAt = msg['sent_at'] as String? ?? '';
    final timeStr = _formatChatTime(sentAt);

    if (isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: AppColors.gradPurple,
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
            child: Text(text,
                style: GoogleFonts.outfit(
                    fontSize: 14, height: 1.45, color: Colors.white)),
          ),
          if (timeStr.isNotEmpty) ...[
            const SizedBox(height: 3),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(text,
                style: GoogleFonts.outfit(
                    fontSize: 14, height: 1.45, color: AppColors.text)),
          ),
          if (timeStr.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(timeStr,
                style:
                    GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
          ],
        ]),
      ),
    ]);
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
  final bool useDirectThread;
  final VoidCallback onReacted;
  const _TrackMessage(
      {required this.msg,
      required this.isMe,
      required this.partnerInitial,
      required this.partnerAvatarUrl,
      required this.matchId,
      required this.chatId,
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
    final reactions = (msg['reactions'] as Map<String, dynamic>?) ?? {};

    final bubble = GestureDetector(
      onLongPress: messageId != null
          ? () => _showReactionPicker(context, messageId)
          : null,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.purple.withOpacity(0.2), width: 1),
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
                      bottom: BorderSide(
                          color: AppColors.purple.withOpacity(0.15))),
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
                                if (useDirectThread) {
                                  await ApiService().reactToDirectMessage(
                                      chatId!, messageId, emoji);
                                } else {
                                  await ApiService().reactToMessage(
                                      matchId!, messageId, emoji);
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

  void _showReactionPicker(BuildContext context, String messageId) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('React',
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text2)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _kReactions.map((emoji) {
              return GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    if (useDirectThread) {
                      await ApiService()
                          .reactToDirectMessage(chatId!, messageId, emoji);
                    } else {
                      await ApiService()
                          .reactToMessage(matchId!, messageId, emoji);
                    }
                    onReacted();
                  } catch (_) {}
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.glass,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 22))),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }
}

class _AlbumMessage extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String partnerInitial;
  final String partnerAvatarUrl;

  const _AlbumMessage({
    required this.msg,
    required this.isMe,
    required this.partnerInitial,
    required this.partnerAvatarUrl,
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
      child: card,
    );
  }
}

class _PlaylistMessage extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String partnerInitial;
  final String partnerAvatarUrl;

  const _PlaylistMessage({
    required this.msg,
    required this.isMe,
    required this.partnerInitial,
    required this.partnerAvatarUrl,
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
      child: card,
    );
  }
}

class _ImageMessage extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String partnerInitial;
  final String partnerAvatarUrl;

  const _ImageMessage({
    required this.msg,
    required this.isMe,
    required this.partnerInitial,
    required this.partnerAvatarUrl,
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
          Image.network(
            imageDataUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 180,
              color: AppColors.surface,
              alignment: Alignment.center,
              child: const Icon(Icons.image_rounded,
                  color: Colors.white70, size: 28),
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
      child: card,
    );
  }
}

class _MessageFrame extends StatelessWidget {
  final bool isMe;
  final String partnerInitial;
  final String partnerAvatarUrl;
  final String timeStr;
  final Widget child;

  const _MessageFrame({
    required this.isMe,
    required this.partnerInitial,
    required this.partnerAvatarUrl,
    required this.timeStr,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (isMe) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(alignment: Alignment.centerRight, child: child),
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
  final void Function(int index) onJumpToMessage;
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
                          onTap: () => widget.onJumpToMessage(item.index),
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
                                      Text(
                                        _snippet(item.text, query),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          color: AppColors.text,
                                          height: 1.4,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
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
        gradient: AppColors.gradMixed,
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
              fit: BoxFit.cover,
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

  const _SharedContentScreen({
    required this.messages,
    required this.partnerName,
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
    _tabCtrl = TabController(length: 5, vsync: this);
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
  List<Map<String, dynamic>> get _playlists => _byType('playlist');
  List<Map<String, dynamic>> get _musicOnly => _byType('track');
  List<Map<String, dynamic>> get _albumsOnly => _byType('album');

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
            Tab(text: 'Albums'),
            Tab(text: 'Playlists'),
            Tab(text: 'Links'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _MusicTab(items: _musicOnly),
          _MediaTab(images: _images),
          _AlbumTab(items: _albumsOnly),
          _PlaylistTab(items: _playlists),
          _LinksTab(links: _links),
        ],
      ),
    );
  }
}

class _MusicTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _MusicTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _SharedEmptyState(
        icon: Icons.music_note_rounded,
        label: 'No music shared yet',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final m = items[i];
        final title = (m['track_title'] ?? 'Unknown').toString();
        final artist = (m['track_artist'] ?? '').toString();
        final coverUrl = (m['track_cover_url'] ?? '').toString();
        final note = (m['note'] ?? '').toString().trim();
        final time = _formatChatTime(m['sent_at']?.toString());

        return _SharedCard(
          icon: Icons.music_note_rounded,
          title: title,
          subtitle: artist,
          tertiary: note.isNotEmpty ? note : null,
          imageUrl: coverUrl,
          time: time,
          badge: 'Track',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlayerScreen(track: m)),
            );
          },
        );
      },
    );
  }
}

class _AlbumTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _AlbumTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _SharedEmptyState(
        icon: Icons.album_rounded,
        label: 'No albums shared yet',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final m = items[i];
        final title = (m['album_title'] ?? 'Album').toString();
        final artist = (m['album_artist'] ?? '').toString();
        final coverUrl = (m['album_cover_url'] ?? '').toString();
        final albumId = int.tryParse((m['album_id'] ?? '').toString());
        final note = (m['note'] ?? '').toString().trim();
        final time = _formatChatTime(m['sent_at']?.toString());
        return _SharedCard(
          icon: Icons.album_rounded,
          title: title,
          subtitle: artist,
          tertiary: note.isNotEmpty ? note : null,
          imageUrl: coverUrl,
          time: time,
          badge: 'Album',
          onTap: albumId == null
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AlbumScreen(albumId: albumId),
                    ),
                  );
                },
        );
      },
    );
  }
}

class _PlaylistTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _PlaylistTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _SharedEmptyState(
        icon: Icons.queue_music_rounded,
        label: 'No playlists shared yet',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final m = items[i];
        final title = (m['playlist_title'] ?? 'Playlist').toString();
        final coverUrl = (m['playlist_cover_url'] ?? '').toString();
        final playlistId = (m['playlist_id'] as num?)?.toInt();
        final note = (m['note'] ?? '').toString().trim();
        final time = _formatChatTime(m['sent_at']?.toString());
        return _SharedCard(
          icon: Icons.queue_music_rounded,
          title: title,
          subtitle: 'Playlist',
          tertiary: note.isNotEmpty ? note : null,
          imageUrl: coverUrl,
          time: time,
          badge: 'Playlist',
          onTap: playlistId == null
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistScreen(playlistId: playlistId),
                    ),
                  );
                },
        );
      },
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

  const _SharedCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tertiary,
    required this.imageUrl,
    required this.time,
    required this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Icon(icon, color: Colors.white70),
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

class _MediaTab extends StatelessWidget {
  final List<Map<String, dynamic>> images;
  const _MediaTab({required this.images});

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
        final url =
            (images[i]['image_url'] ?? images[i]['url'] ?? '').toString();
        if (url.isEmpty) return const SizedBox.shrink();
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.surface),
                  errorWidget: (_, __, ___) => Container(
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
        );
      },
    );
  }
}

class _LinksTab extends StatelessWidget {
  final List<Map<String, dynamic>> links;
  const _LinksTab({required this.links});

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
