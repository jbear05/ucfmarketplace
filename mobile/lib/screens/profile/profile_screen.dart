import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/star_rating.dart';

// Predefined avatars
const _avatars = [
  {'key': 'student_male',   'label': 'Student M',  'icon': Icons.school_rounded,      'color': Color(0xFF4ECDC4)},
  {'key': 'student_female', 'label': 'Student F',  'icon': Icons.school_rounded,      'color': Color(0xFFFF6B6B)},
  {'key': 'lister_male',    'label': 'Seller M',   'icon': Icons.storefront_rounded,  'color': Color(0xFF6C63FF)},
  {'key': 'lister_female',  'label': 'Seller F',   'icon': Icons.storefront_rounded,  'color': Color(0xFFFFE66D)},
  {'key': 'graduate',       'label': 'Graduate',   'icon': Icons.military_tech_rounded,'color': Color(0xFF34C759)},
  {'key': 'professional',   'label': 'Professional','icon': Icons.work_rounded,       'color': Color(0xFF38B2AA)},
];

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) return const _GuestView();
    return _AuthenticatedView(auth: auth);
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded, size: 44, color: AppTheme.primary),
              ),
              const SizedBox(height: 24),
              const Text('Sign in to KnightMarket',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              const Text('Create an account or log in to save listings, send messages, and list your place.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 32),
              SizedBox(width: double.infinity,
                  child: ElevatedButton(onPressed: () => context.push('/login'), child: const Text('Log In'))),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity,
                  child: OutlinedButton(onPressed: () => context.push('/register'), child: const Text('Create Account'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthenticatedView extends StatelessWidget {
  final AuthProvider auth;
  const _AuthenticatedView({required this.auth});

  @override
  Widget build(BuildContext context) {
    final user      = auth.user!;
    final avatarKey = user.avatarKey;
    final avatarData = _avatars.firstWhere(
      (a) => a['key'] == avatarKey,
      orElse: () => _avatars[0],
    );

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: const Text('Profile'), centerTitle: false),
      body: ListView(
        children: [
          // ── Header ─────────────────────────────────────────────
          Container(
            color: AppTheme.bgCard,
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _showAvatarPicker(context),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: (avatarData['color'] as Color).withValues(alpha: 0.2),
                        child: Icon(avatarData['icon'] as IconData,
                            size: 36, color: avatarData['color'] as Color),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.edit_rounded, size: 13, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(user.email, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Row(children: [
                        if (user.isVerifiedStudent) ...[
                          const Icon(Icons.verified_rounded, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          const Text('Verified Student',
                              style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 12),
                        ],
                        if (user.isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Admin',
                                style: TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.w600)),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      StarRatingDisplay(rating: user.ratingAvg, count: user.ratingCount),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Menu ───────────────────────────────────────────────
          Container(
            color: AppTheme.bgCard,
            child: Column(children: [
              _MenuItem(
                icon: Icons.home_outlined,
                label: 'My Listings',
                onTap: () => context.push('/my-listings'),
              ),
              if (user.isAdmin) ...[
                const Divider(height: 1, indent: 56, color: AppTheme.border),
                _MenuItem(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Admin Dashboard',
                  color: AppTheme.primary,
                  onTap: () => context.push('/admin'),
                ),
              ],
              const Divider(height: 1, indent: 56, color: AppTheme.border),
              _MenuItem(
                icon: Icons.support_agent_rounded,
                label: 'Contact Admin',
                onTap: () => _showContactAdmin(context),
              ),
              const Divider(height: 1, indent: 56, color: AppTheme.border),
              _MenuItem(
                icon: Icons.logout_rounded,
                label: 'Log Out',
                color: AppTheme.error,
                onTap: () => _confirmLogout(context),
              ),
            ]),
          ),

          const SizedBox(height: 32),
          const Center(child: Text('KnightMarket v1.0.0',
              style: TextStyle(fontSize: 12, color: AppTheme.textLight))),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showAvatarPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Choose Avatar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: _avatars.map((a) {
                final isSelected = auth.user?.avatarKey == a['key'];
                return GestureDetector(
                  onTap: () {
                    context.read<AuthProvider>().updateAvatar(a['key'] as String);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (a['color'] as Color).withValues(alpha: 0.2)
                          : AppTheme.bgInput,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? a['color'] as Color : AppTheme.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(a['icon'] as IconData, size: 32, color: a['color'] as Color),
                        const SizedBox(height: 6),
                        Text(a['label'] as String,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showContactAdmin(BuildContext context) {
    final ctrl = TextEditingController();
    final chat = context.read<ChatProvider>();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Contact Admin',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            const Text('Send us a message and we\'ll get back to you.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLines: 4,
              enabled: !isSending,
              decoration: const InputDecoration(
                  hintText: 'Describe your issue or question...'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSending ? null : () async {
                  if (ctrl.text.trim().isEmpty) return;
                  setSheetState(() => isSending = true);
                  final result = await chat.contactAdmin(ctrl.text.trim());
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  if (result.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.error!)),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message sent to admin')),
                    );
                    context.push('/messages/${result.threadId}');
                  }
                },
                child: const Text('Send Message'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: AppTheme.error, size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Log Out?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            const Text('You can always log back in.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Tear down the socket before clearing auth — otherwise it
                  // stays connected under this account and leaks into
                  // whichever account logs in next.
                  context.read<ChatProvider>().disconnectSocket();
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) context.go('/');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.textSecondary, size: 22),
      title: Text(label, style: TextStyle(fontSize: 15, color: c)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
