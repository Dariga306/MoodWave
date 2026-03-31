import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final int matchId;
  final String partnerName;
  final int partnerId;

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.partnerName,
    required this.partnerId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<dynamic> _messages = [];
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await ApiService().getChatMessages(widget.matchId);
      if (!mounted) return;
      setState(() => _messages = msgs);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _textCtrl.clear();
    try {
      await ApiService().sendTextMessage(widget.matchId, text);
      await _loadMessages();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthProvider>().user?['id'];
    final partnerInitial =
        widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.bg2,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.arrow_back_rounded,
                            color: AppColors.text, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradMixed,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.1), width: 2),
                      ),
                      child: Center(
                        child: Text(partnerInitial,
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.partnerName,
                              style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text)),
                          Text('Music match',
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.purpleLight)),
                        ],
                      ),
                    ),
                    const Icon(Icons.queue_music_rounded,
                        size: 22, color: AppColors.purpleLight),
                  ],
                ),
              ),
            ),
          ),
          Container(height: 1, color: AppColors.border),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🎵', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text('Say hi to ${widget.partnerName}!',
                            style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text)),
                        const SizedBox(height: 4),
                        Text('You matched on music taste',
                            style: GoogleFonts.outfit(
                                fontSize: 13, color: AppColors.text3)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i] as Map<String, dynamic>;
                      final isMe = msg['sender_id'] == myId;
                      final type = msg['type'] ?? 'text';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: type == 'track'
                            ? _TrackMessage(msg: msg, isMe: isMe,
                                partnerInitial: partnerInitial)
                            : _TextMessage(msg: msg, isMe: isMe,
                                partnerInitial: partnerInitial),
                      );
                    },
                  ),
          ),

          // Input
          Container(
            color: AppColors.bg2,
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textCtrl,
                            style: GoogleFonts.outfit(
                                fontSize: 15, color: AppColors.text),
                            maxLength: 100,
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              hintStyle: GoogleFonts.outfit(
                                  fontSize: 15, color: AppColors.text3),
                              border: InputBorder.none,
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradPurple,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.purpleDark.withOpacity(0.4),
                            blurRadius: 12)
                      ],
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
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

class _TextMessage extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String partnerInitial;
  const _TextMessage(
      {required this.msg, required this.isMe, required this.partnerInitial});

  @override
  Widget build(BuildContext context) {
    final text = msg['text'] ?? '';
    final sentAt = msg['sent_at'] as String? ?? '';
    final timeStr = sentAt.length >= 16 ? sentAt.substring(11, 16) : '';

    if (isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.gradPurple,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Text(text,
                  style: GoogleFonts.outfit(
                      fontSize: 14, height: 1.5, color: Colors.white)),
            ),
            if (timeStr.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(timeStr,
                  style:
                      GoogleFonts.outfit(fontSize: 10, color: AppColors.text3)),
            ],
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration:
              BoxDecoration(gradient: AppColors.gradMixed, shape: BoxShape.circle),
          child: Center(
              child: Text(partnerInitial,
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white))),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(6),
                  ),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(text,
                    style: GoogleFonts.outfit(
                        fontSize: 14, height: 1.5, color: AppColors.text)),
              ),
              if (timeStr.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(timeStr,
                    style: GoogleFonts.outfit(
                        fontSize: 10, color: AppColors.text3)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackMessage extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String partnerInitial;
  const _TrackMessage(
      {required this.msg, required this.isMe, required this.partnerInitial});

  @override
  Widget build(BuildContext context) {
    final title = msg['track_title'] ?? 'Unknown track';
    final artist = msg['track_artist'] ?? '';
    final phrase = msg['phrase'] ?? '';
    final phraseEmoji = msg['phrase_emoji'] ?? '🎵';

    final bubble = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (phrase.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('$phraseEmoji $phrase',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.text2)),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.gradMixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: Text('🎵', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text),
                        overflow: TextOverflow.ellipsis),
                    if (artist.isNotEmpty)
                      Text(artist,
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppColors.text2),
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return isMe
        ? Align(alignment: Alignment.centerRight, child: bubble)
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    gradient: AppColors.gradMixed, shape: BoxShape.circle),
                child: Center(
                    child: Text(partnerInitial,
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white))),
              ),
              const SizedBox(width: 8),
              Flexible(child: bubble),
            ],
          );
  }
}
