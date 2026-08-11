import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  // Update these to your real support channels when you have them —
  // placeholders for now so the buttons are honestly functional rather than
  // pointing at fake info.
  static const _supportPhone = '+911234567890';
  static const _supportEmail = 'support@wheeldeal.com';

  static const _faqs = [
    (
      'How do I list a vehicle for sale?',
      'Go to the Sell tab, fill in the vehicle details and add at least one real photo, then tap Submit Listing. It goes live immediately and shows up in Search and Home right away.',
    ),
    (
      'How do I edit or remove a listing?',
      'Open Profile → My Listings, tap the vehicle you want to change, update the details, and tap Save Changes.',
    ),
    (
      'Can I edit or delete a chat message after sending it?',
      'Long-press a message you sent. Editing is available for 15 minutes after sending; deleting is available for the same window. After that, the message is locked.',
    ),
    (
      'How does "Request Callback" work?',
      "It sends the seller a notification with your phone number so they can call you back directly — you don't need to share your number in chat.",
    ),
    (
      'Is my phone number visible to everyone?',
      "Only to a buyer who actually opens the Contact Seller sheet on your listing, and only after they choose Call, WhatsApp, or Request Callback — it isn't shown anywhere else in the app.",
    ),
  ];

  // -1 means nothing is expanded. Only one FAQ open at a time keeps the
  // list scannable instead of turning into a wall of text — this is the
  // same accordion pattern Myntra/Snitch-style help centers use.
  int _expandedIndex = -1;

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: _supportPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _showUnavailable();
    }
  }

  Future<void> _whatsapp() async {
    final cleaned = _supportPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _showUnavailable();
    }
  }

  Future<void> _email() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=${Uri.encodeComponent('WheelDeal support request')}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _showUnavailable();
    }
  }

  void _showUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No app found to handle this action on your device')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            'How can we help you?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            "Reach our team directly, or check the answers below — most\nquestions are covered here.",
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ContactCard(
                  icon: Icons.call_outlined,
                  label: 'Call us',
                  subtitle: '9am–7pm',
                  color: AppColors.primary,
                  onTap: _call,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ContactCard(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  subtitle: 'Instant reply',
                  color: const Color(0xFF25B45B),
                  onTap: _whatsapp,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ContactCard(
                  icon: Icons.mail_outline,
                  label: 'Email us',
                  subtitle: 'Within 24h',
                  color: const Color(0xFF4C7CD9),
                  onTap: _email,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Frequently asked questions',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '${_faqs.length} topics',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          ...List.generate(_faqs.length, (i) {
            final isOpen = _expandedIndex == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FaqCard(
                question: _faqs[i].$1,
                answer: _faqs[i].$2,
                isOpen: isOpen,
                onTap: () => setState(() => _expandedIndex = isOpen ? -1 : i),
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Still stuck?',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Send us a note and we'll get back to you.",
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _email,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Email us'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  final String question;
  final String answer;
  final bool isOpen;
  final VoidCallback onTap;

  const _FaqCard({
    required this.question,
    required this.answer,
    required this.isOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isOpen ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Regular weight, not bold — a whole screen of bold text
                  // is what made the old version feel congested and gave
                  // the eye nothing to rest on. Only the section headers
                  // above are actually bold now.
                  Expanded(
                    child: Text(
                      question,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 22),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    answer,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
                crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}