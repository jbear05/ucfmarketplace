import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';

/// Everything that's actually real today: profile fields, and the one
/// notification preference with a working delivery channel behind it
/// (price-drop email). No toggles for things that don't do anything yet —
/// see the Word doc for why the original 6-toggle version was cut down.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _classYearCtrl;
  late bool _emailPriceDrop;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _nameCtrl       = TextEditingController(text: user.name);
    _classYearCtrl  = TextEditingController(text: user.classYear ?? '');
    _emailPriceDrop = user.emailPriceDrop;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _classYearCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final err = await context.read<AuthProvider>().updateProfile(
      name:           _nameCtrl.text.trim(),
      classYear:      _classYearCtrl.text.trim(),
      emailPriceDrop: _emailPriceDrop,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _classYearCtrl,
            decoration: const InputDecoration(labelText: 'Class Year', hintText: 'e.g. 27'),
          ),
          const SizedBox(height: 28),
          Text('Display', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          SwitchListTile(
            value: context.watch<ThemeController>().isDark,
            onChanged: (v) => context.read<ThemeController>().setDark(v),
            contentPadding: EdgeInsets.zero,
            title: Text('Dark mode', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
          ),
          const SizedBox(height: 28),
          Text('Notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(
            'KnightMarket has no push notifications yet — this controls email only.',
            style: TextStyle(fontSize: 12, color: AppTheme.textLight),
          ),
          SwitchListTile(
            value: _emailPriceDrop,
            onChanged: (v) => setState(() => _emailPriceDrop = v),
            contentPadding: EdgeInsets.zero,
            title: Text('Email me about listing alerts', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
            subtitle: Text('Price drops on favorites, and new matches for saved searches',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
