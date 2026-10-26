import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../config/community_rules.dart';

/// Renders whatever is in kCommunityRules — has no rules content of its own.
class CommunityRulesScreen extends StatelessWidget {
  const CommunityRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Community Rules'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(kCommunityRulesIntro,
                style: TextStyle(
                    fontSize: 15, color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 28),
            for (final section in kCommunityRules) ...[
              _RuleTile(section: section),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final RuleSection section;
  const _RuleTile({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        Text(section.body,
            style: TextStyle(
                fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),
      ],
    );
  }
}
