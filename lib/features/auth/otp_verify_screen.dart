import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../services/providers/auth_provider.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpVerifyScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  String _code = '';
  bool _verifying = false;
  String? _error;

  Future<void> _verify() async {
    if (_code.length != 6) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    // Pure UI-testing mode — no real Firebase involved, just log in as the
    // mock user (see AuthNotifier.loginWithFirebasePhone).
    if (ApiConstants.useMockData) {
      final ok = await ref.read(authProvider.notifier).loginWithFirebasePhone('mock-token');
      if (ok && mounted) {
        context.go('/');
      } else if (mounted) {
        setState(() {
          _verifying = false;
          _error = 'Could not sign you in. Please try again.';
        });
      }
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _code,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user!.getIdToken();

      final ok = await ref.read(authProvider.notifier).loginWithFirebasePhone(idToken!);

      if (ok && mounted) {
        context.go('/');
      } else if (mounted) {
        setState(() {
          _verifying = false;
          _error = ref.read(authProvider).error ?? 'Could not sign you in. Please try again.';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _verifying = false;
        _error = switch (e.code) {
          'invalid-verification-code' => 'That code is incorrect. Check and try again.',
          'session-expired' => 'This code has expired. Go back and request a new one.',
          _ => e.message ?? 'Verification failed.',
        };
      });
    } catch (e) {
      setState(() {
        _verifying = false;
        _error = 'Verification failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter the code',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to ${widget.phoneNumber}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              PinCodeTextField(
                appContext: context,
                length: 6,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 50,
                  fieldWidth: 44,
                  activeColor: AppColors.primary,
                  selectedColor: AppColors.primary,
                  inactiveColor: AppColors.inputBackground,
                  activeFillColor: AppColors.inputBackground,
                  selectedFillColor: AppColors.inputBackground,
                  inactiveFillColor: AppColors.inputBackground,
                ),
                onChanged: (v) => _code = v,
                onCompleted: (v) {
                  _code = v;
                  _verify();
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  child: _verifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify & Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
