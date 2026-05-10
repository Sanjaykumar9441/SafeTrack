import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch $url");
    }
  }

  void _launchEmail(String email) async {
    final uri = Uri.parse(
      'mailto:$email?subject=SafeTrack%20Support&body=Hello%20SafeTrack%20Team,',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch email app");
    }
  }

  void _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Contact'),
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          children: [
            // ── Hero header ──
            _buildHeroCard(),
            const SizedBox(height: 20),

            _buildSection(
              icon: Icons.person_rounded,
              iconColor: const Color(0xFF3B82F6),
              title: 'Developer Information',
              children: [
                _buildInfoRow(Icons.person_outline, 'Name', 'Sanjay Kumar'),
                _buildInfoRow(
                    Icons.school_outlined, 'College', 'Aditya University'),
                _buildInfoRow(Icons.work_outline, 'Department',
                    'Electronics & Communication (ECE)'),
                _buildInfoRow(Icons.rocket_launch_outlined, 'Project',
                    'SafeTrack — Project Space 2026'),
                _buildInfoRow(
                  Icons.email_outlined,
                  'Email',
                  'bus.alert.track@gmail.com',
                  onTap: () => _launchEmail('bus.alert.track@gmail.com'),
                ),
                _buildInfoRow(
                  Icons.phone_outlined,
                  'Phone',
                  '+91 70950 09441',
                  onTap: () => _launchPhone('+917095009441'),
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildSection(
              icon: Icons.info_outline_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Project Information',
              children: [
                _buildInfoRow(
                    Icons.category_outlined, 'Type', 'Safe Drive Alert System'),
                _buildInfoRow(Icons.memory_outlined, 'Hardware',
                    'ESP32, GPS, Flame, MQ-2, MPU6050'),
                _buildInfoRow(Icons.code_rounded, 'Tech Stack',
                    'Flutter · Firebase · ESP32 · React'),
                _buildInfoRow(
                    Icons.cloud_outlined, 'Backend', 'Firestore (real-time)'),
                _buildInfoRow(Icons.workspace_premium_outlined, 'Standard',
                    'IEEE Paper Published',
                    isLast: true),
              ],
            ),
            const SizedBox(height: 14),

            _buildSection(
              icon: Icons.support_agent_rounded,
              iconColor: AppTheme.safeColor,
              title: 'Bus Helpline',
              children: [
                _buildActionButton(
                  Icons.phone_rounded,
                  'Call Helpline',
                  null,
                  AppTheme.safeColor,
                  () => _launchPhone('+917095009441'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildSection(
              icon: Icons.help_outline_rounded,
              iconColor: AppTheme.dangerColor,
              title: 'Support',
              children: [
                _buildActionButton(
                  Icons.bug_report_outlined,
                  'Report an Issue',
                  'Found a bug? Let us know',
                  AppTheme.dangerColor,
                  () => _launchEmail('bus.alert.track@gmail.com'),
                ),
                const SizedBox(height: 10),
                _buildActionButton(
                  Icons.feedback_outlined,
                  'Send Feedback',
                  'We appreciate your feedback',
                  AppTheme.primaryColor,
                  () => _launchUrl('https://forms.gle/XbQZQB7k8y177mLf8'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildSection(
              icon: Icons.link_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Links',
              children: [
                _buildLinkButton(
                  Icons.code_rounded,
                  'GitHub Repository',
                  () => _launchUrl(
                      'https://github.com/Sanjaykumar9441/SafeTrack_ProjectSpace2026/tree/main'),
                ),
                _buildLinkButton(
                  Icons.language_rounded,
                  'Admin Portal',
                  () => _launchUrl('https://safedrive-144.web.app'),
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 28),
            _buildFooter(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Hero card ─────────────────────────────────────────────
  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Text(
                'SK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sanjay Kumar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ECE — Aditya University',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _heroBadge('SafeTrack'),
                    const SizedBox(width: 8),
                    _heroBadge('v1.0.0'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Section card ──────────────────────────────────────────
  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),

          // Separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Container(
              height: 0.5,
              color: Colors.grey.withValues(alpha: 0.15),
            ),
          ),

          // Children
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  // ── Info row ──────────────────────────────────────────────
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onTap != null
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.grey.withValues(alpha: 0.1),
          ),
      ],
    );
  }

  // ── Action button ─────────────────────────────────────────
  Widget _buildActionButton(
    IconData icon,
    String title,
    String? subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontSize: 14,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Link button ───────────────────────────────────────────
  Widget _buildLinkButton(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 10,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: Colors.grey.withValues(alpha: 0.1),
          ),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────
  Widget _buildFooter() {
    return Column(
      children: [
        // IEEE badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF00629B).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF00629B).withValues(alpha: 0.2),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                size: 14,
                color: Color(0xFF00629B),
              ),
              SizedBox(width: 6),
              Text(
                'Project Space 2026',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00629B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '© 2026 SafeTrack — Aditya University ECE',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version 1.0.0',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
