import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../models/message.dart';
import '../../models/thread.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../map/meetup_picker_screen.dart';
import '../../widgets/star_rating.dart';

class ChatThreadScreen extends StatefulWidget {
  final String threadId;
  final Thread? thread;

  const ChatThreadScreen({
    super.key,
    required this.threadId,
    this.thread,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  ChatProvider? _chatProvider;

  int _prevMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _chatProvider = context.read<ChatProvider>();
      _chatProvider!.setActiveThread(widget.threadId);
      _chatProvider!.addListener(_onChatUpdate);
      await _chatProvider!.openThread(widget.threadId);
      _scrollToBottom();
    });
  }

  void _onChatUpdate() {
    final chat = context.read<ChatProvider>();
    final count = chat.messagesFor(widget.threadId).length;
    if (count > _prevMessageCount) {
      _prevMessageCount = count;
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _chatProvider
      ?..removeListener(_onChatUpdate)
      ..closeThread(widget.threadId);
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

  Future<void> _showRatingDialog(String otherName) async {
    int score = 5;
    final feedbackCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: Text('Rate $otherName', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How did the exchange go?',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              StarRatingInput(value: score, onChanged: (v) => setDialogState(() => score = v)),
              const SizedBox(height: 16),
              TextField(
                controller: feedbackCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Leave feedback (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Skip', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted) return;
    final err = await context.read<ChatProvider>().rateThread(
      widget.threadId,
      score: score,
      feedback: feedbackCtrl.text,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Thanks for your feedback!')),
      );
    }
  }

  Future<void> _shareContact() async {
    final ctrl = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share your number?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This posts your number as a message in this conversation only — it is not shared anywhere else.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number', hintText: '(407) 555-0100'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('Share'),
          ),
        ],
      ),
    );
    if (phone == null || phone.isEmpty || !mounted) return;
    final err = await context.read<ChatProvider>().shareContact(widget.threadId, phone);
    if (mounted && err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _arrangeMeetup() async {
    final result = await context.push<MeetupPickResult>('/messages/${widget.threadId}/meetup');
    if (result == null || !mounted) return;
    final err = await context.read<ChatProvider>().proposeMeetup(
      widget.threadId,
      address: result.address,
      lat: result.lat,
      lng: result.lng,
      scheduledAt: result.scheduledAt,
    );
    if (mounted && err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _isSending = true);

    final msg =
        await context.read<ChatProvider>().sendMessage(widget.threadId, text);

    setState(() => _isSending = false);

    if (msg != null) {
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    final chat = context.watch<ChatProvider>();
    final auth = context.read<AuthProvider>();
    final messages = chat.messagesFor(widget.threadId);
    final userId = auth.user?.id ?? '';

    // Use live thread from provider for up-to-date isBlocked state
    final liveThread = chat.threads.firstWhere(
      (t) => t.id == widget.threadId,
      orElse: () => widget.thread ?? Thread(id: widget.threadId, participants: [], unreadCount: 0),
    );
    final isBlocked = liveThread.isBlocked;

    String title = 'Chat';
    final other = liveThread.participants.firstWhere(
      (p) => p.id != userId,
      orElse: () => liveThread.participants.isNotEmpty
          ? liveThread.participants[0]
          : ThreadParticipant(id: '', name: ''),
    );
    if (other.name.isNotEmpty) title = other.name;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            if (liveThread.listingSnapshot != null)
              Text(
                '\$${liveThread.listingSnapshot!.price.toStringAsFixed(0)} • ${liveThread.listingSnapshot!.title}',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppTheme.textPrimary),
            onSelected: (val) async {
              if (val == 'meetup') {
                _arrangeMeetup();
              }
              if (val == 'share_contact') {
                _shareContact();
              }
              if (val == 'block') {
                await chat.blockThread(widget.threadId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isBlocked ? 'Conversation unblocked' : 'Conversation blocked')),
                  );
                }
              }
              if (val == 'delete') {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete conversation?'),
                    content: const Text('This will remove the conversation from your inbox.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          chat.deleteThread(widget.threadId);
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              if (liveThread.meetup.status == 'none' || liveThread.meetup.status == 'cancelled')
                PopupMenuItem(
                  value: 'meetup',
                  child: Row(children: [
                    Icon(Icons.location_on_rounded, size: 18, color: AppTheme.primary),
                    SizedBox(width: 10),
                    Text('Arrange meetup'),
                  ]),
                ),
              PopupMenuItem(
                value: 'share_contact',
                child: Row(children: [
                  Icon(Icons.phone_rounded, size: 18, color: AppTheme.primary),
                  SizedBox(width: 10),
                  Text('Share my number'),
                ]),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(children: [
                  Icon(Icons.block_rounded, size: 18, color: isBlocked ? AppTheme.error : AppTheme.warning),
                  const SizedBox(width: 10),
                  Text(isBlocked ? 'Unblock conversation' : 'Block conversation'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                  SizedBox(width: 10),
                  Text('Delete conversation', style: TextStyle(color: AppTheme.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Blocked banner
          if (isBlocked)
            Container(
              width: double.infinity,
              color: AppTheme.error.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Icon(Icons.block_rounded, size: 16, color: AppTheme.error),
                SizedBox(width: 8),
                Expanded(
                  child: Text('This conversation is blocked — no new messages can be sent.',
                      style: TextStyle(fontSize: 13, color: AppTheme.error)),
                ),
              ]),
            ),

          if (liveThread.meetup.status != 'none' && liveThread.meetup.status != 'cancelled')
            _MeetupBanner(
              thread: liveThread,
              currentUserId: userId,
              hasRated: chat.hasRated(widget.threadId),
              onConfirm: () => context.read<ChatProvider>().respondMeetup(widget.threadId, 'confirm'),
              onCancel: () => context.read<ChatProvider>().respondMeetup(widget.threadId, 'cancel'),
              onComplete: () => context.read<ChatProvider>().completeMeetup(widget.threadId),
              onRate: () => _showRatingDialog(other.name),
            ),

          // Messages
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text('No messages yet. Say hello!',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final isMe = msg.sender.id == userId;
                      final showDate = i == 0 ||
                          messages[i - 1]
                                  .createdAt
                                  .difference(msg.createdAt)
                                  .abs()
                                  .inMinutes >
                              10;
                      return Column(
                        children: [
                          if (showDate)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                _formatDate(msg.createdAt),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textLight),
                              ),
                            ),
                          _MessageBubble(message: msg, isMe: isMe),
                        ],
                      );
                    },
                  ),
          ),

          // Input
          Container(
            color: AppTheme.bgCard,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: isBlocked ? AppTheme.bgElevated : AppTheme.bgInput,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: TextField(
                      controller: _messageController,
                      enabled: !isBlocked,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: isBlocked ? 'Conversation blocked' : 'Message...',
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        hintStyle: TextStyle(color: AppTheme.textLight),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: (_isSending || isBlocked) ? null : _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isBlocked ? AppTheme.textLight : AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(Icons.send_rounded,
                            color: isBlocked ? Colors.white : Colors.black, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today ${DateFormat.jm().format(dt)}';
    }
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day - 1) {
      return 'Yesterday ${DateFormat.jm().format(dt)}';
    }
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}

/// Opens Google Maps with the meetup as the destination — uses the native
/// app if installed, falls back to the browser otherwise. Prefers an exact
/// pin when we have one; falls back to a text search on the address.
/// Hands the confirmed meetup off to the phone's own calendar/reminder
/// system — no push infrastructure needed, and the user picks their own
/// reminder lead time same as any other calendar event. Uses a Google
/// Calendar template link (opens the Calendar app if installed, the web
/// otherwise) rather than a native calendar plugin — add_2_calendar's
/// bundled Android build script has an upstream Kotlin/Gradle
/// incompatibility with this project, so this reuses the same url_launcher
/// approach already proven for "Get Directions" instead.
Future<void> _addToCalendar(ThreadMeetup meetup, String otherPersonName) async {
  final start = meetup.scheduledAt ?? DateTime.now().add(const Duration(hours: 1));
  final end = start.add(const Duration(minutes: 30));
  String fmt(DateTime d) => d.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]|\.\d+'), '');

  final uri = Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': 'KnightMarket meetup with $otherPersonName',
    'dates': '${fmt(start)}/${fmt(end)}',
    'details': 'Arranged via KnightMarket',
    'location': meetup.address ?? '',
  });
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _openDirections(ThreadMeetup meetup) async {
  final uri = (meetup.lat != null && meetup.lng != null)
      ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${meetup.lat},${meetup.lng}')
      : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(meetup.address ?? '')}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _MeetupBanner extends StatelessWidget {
  final Thread thread;
  final String currentUserId;
  final bool hasRated;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onComplete;
  final VoidCallback onRate;

  const _MeetupBanner({
    required this.thread,
    required this.currentUserId,
    required this.hasRated,
    required this.onConfirm,
    required this.onCancel,
    required this.onComplete,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final meetup = thread.meetup;
    final isProposer = meetup.proposedBy == currentUserId;
    final iConfirmedCompletion = meetup.confirmedBy.contains(currentUserId);
    final when = meetup.scheduledAt != null
        ? DateFormat('MMM d, h:mm a').format(meetup.scheduledAt!)
        : null;

    String headline;
    List<Widget> actions = [];

    switch (meetup.status) {
      case 'proposed':
        headline = isProposer
            ? 'Waiting for the other person to confirm the meetup'
            : 'Meetup proposed';
        if (!isProposer) {
          actions = [
            TextButton(onPressed: onCancel, child: Text('Decline', style: TextStyle(color: AppTheme.error))),
            ElevatedButton(onPressed: onConfirm, child: const Text('Confirm')),
          ];
        } else {
          actions = [TextButton(onPressed: onCancel, child: Text('Cancel', style: TextStyle(color: AppTheme.error)))];
        }
        break;
      case 'confirmed':
        headline = 'Meetup confirmed';
        final otherPerson = thread.participants.firstWhere(
          (p) => p.id != currentUserId,
          orElse: () => ThreadParticipant(id: '', name: 'the other person'),
        );
        actions = [
          OutlinedButton.icon(
            onPressed: () => _addToCalendar(meetup, otherPerson.name),
            icon: const Icon(Icons.event_available_rounded, size: 16),
            label: const Text('Add to Calendar'),
          ),
          ElevatedButton.icon(
            onPressed: iConfirmedCompletion ? null : onComplete,
            icon: const Icon(Icons.handshake_rounded, size: 16),
            label: Text(iConfirmedCompletion ? 'Waiting for the other person…' : 'Mark Exchange Complete'),
          ),
        ];
        break;
      case 'completed':
        headline = 'Exchange completed — item marked as sold';
        if (!hasRated) {
          actions = [
            ElevatedButton.icon(
              onPressed: onRate,
              icon: const Icon(Icons.star_rounded, size: 16),
              label: const Text('Rate this Exchange'),
            ),
          ];
        }
        break;
      default:
        headline = '';
    }

    return Container(
      width: double.infinity,
      color: AppTheme.primaryLight,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.location_on_rounded, size: 16, color: AppTheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(headline,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            ),
          ]),
          if (meetup.address != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(meetup.address!,
                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                TextButton.icon(
                  onPressed: () => _openDirections(meetup),
                  icon: const Icon(Icons.directions_rounded, size: 16),
                  label: const Text('Directions', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
          if (when != null) ...[
            const SizedBox(height: 2),
            Text(when, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 4,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : AppTheme.bgCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.black : AppTheme.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              DateFormat.jm().format(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe
                    ? Colors.black.withOpacity(0.6)
                    : AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
