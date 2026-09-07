import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../models/thread.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().fetchThreads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: false,
      ),
      body: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : provider.threads.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 52, color: AppTheme.textLight),
                      SizedBox(height: 16),
                      Text('No conversations yet',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      SizedBox(height: 6),
                      Text('Contact a lister to start a conversation',
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () => context.read<ChatProvider>().fetchThreads(),
                  child: ListView.separated(
                    itemCount: provider.threads.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 80),
                    itemBuilder: (_, i) => _ThreadTile(
                      thread: provider.threads[i],
                      currentUserId:
                          context.read<AuthProvider>().user?.id ?? '',
                    ),
                  ),
                ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final Thread thread;
  final String currentUserId;

  const _ThreadTile({required this.thread, required this.currentUserId});

  String _otherParticipantName() {
    final other = thread.participants.firstWhere(
      (p) => p.id != currentUserId,
      orElse: () => thread.participants.isNotEmpty
          ? thread.participants[0]
          : ThreadParticipant(id: '', name: 'Unknown'),
    );
    return other.name.isNotEmpty ? other.name : 'User';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = thread.unreadCount > 0;
    final otherName = _otherParticipantName();

    return GestureDetector(
      onTap: () {
        context.push('/messages/${thread.id}', extra: thread);
      },
      onLongPress: () => _showOptions(context),
      child: Container(
        color: AppTheme.bgDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.bgElevated,
              backgroundImage: thread.listingSnapshot?.mainImage != null
                  ? CachedNetworkImageProvider(
                      thread.listingSnapshot!.mainImage!)
                  : null,
              child: thread.listingSnapshot?.mainImage == null
                  ? Text(
                      otherName[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (thread.lastMessageAt != null)
                        Text(
                          _formatTime(thread.lastMessageAt!),
                          style: TextStyle(
                            fontSize: 11,
                            color: hasUnread
                                ? AppTheme.primary
                                : AppTheme.textLight,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  if (thread.listingSnapshot != null)
                    Text(
                      thread.listingSnapshot!.title,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.lastMessage ?? 'Start a conversation...',
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            thread.unreadCount > 99
                                ? '99+'
                                : '${thread.unreadCount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 7) return DateFormat('MMM d').format(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d';
    if (diff.inHours >= 1) return '${diff.inHours}h';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return 'now';
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.block_rounded,
                  color: thread.isBlocked ? AppTheme.error : AppTheme.warning),
              title: Text(thread.isBlocked ? 'Unblock Conversation' : 'Block Conversation'),
              onTap: () {
                Navigator.pop(context);
                context.read<ChatProvider>().blockThread(thread.id);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
              title: const Text('Delete Conversation',
                  style: TextStyle(color: AppTheme.error)),
              onTap: () {
                Navigator.pop(context);
                context.read<ChatProvider>().deleteThread(thread.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
