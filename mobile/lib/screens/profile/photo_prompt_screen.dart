import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

/// Shown once, gated right before a user's first listing or purchase
/// action — not at signup. Skippable; skipping (or completing) marks
/// hasSeenPhotoPrompt so it never shows again.
class PhotoPromptScreen extends StatefulWidget {
  /// Where to go once this screen is done (choose, skip, or upload failure).
  final String continueTo;
  const PhotoPromptScreen({super.key, required this.continueTo});

  @override
  State<PhotoPromptScreen> createState() => _PhotoPromptScreenState();
}

class _PhotoPromptScreenState extends State<PhotoPromptScreen> {
  final _api = ApiService();
  bool _isSubmitting = false;

  void _continue() {
    if (!mounted) return;
    context.pushReplacement(widget.continueTo);
  }

  Future<void> _choosePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(picked.path, filename: picked.name),
      });
      final res = await _api.postMultipart('/auth/me/avatar', formData);
      final updatedUser = res.data['data']['user'];
      if (mounted && updatedUser != null) {
        context.read<AuthProvider>().applyUserUpdate(updatedUser);
      }
      _continue();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload photo — you can add one later from Settings')),
        );
        await _skip();
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _skip() async {
    try {
      await _api.post('/auth/me/photo-prompt-seen');
    } catch (_) {
      // Non-critical — worst case it asks again next time
    }
    _continue();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeController>();
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.border, width: 1.5),
                ),
                child: Icon(Icons.camera_alt_rounded, size: 36, color: AppTheme.primary),
              ),
              const SizedBox(height: 24),
              Text('Add a profile photo',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              Text(
                'Buyers and sellers trust real faces. You can skip for now — we\'ll only ask this once.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _choosePhoto,
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Choose Photo'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isSubmitting ? null : _skip,
                  child: const Text('Skip for now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
