import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint("Could not launch $url");
    }
  }

  void _launchEmail(String email) async {
    final uri = Uri.parse(
      'mailto:$email?subject=SafeTrack%20Support&body=Hello%20SafeTrack%20Team,',
    );

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
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
      appBar: AppBar(
        title: const Text('Contact'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSection(
              icon: Icons.person,
              title: 'Developer Information',
              children: [
                _buildInfoRow(Icons.person_outline, 'Name', 'Sanjay Kumar'),
                _buildInfoRow(Icons.school, 'College', 'Aditya University'),
                _buildInfoRow(Icons.work, 'Department',
                    'Electronics & Communication (ECE)'),
                _buildInfoRow(
                    Icons.article, 'Project', 'SafeTrack — Project Space 2026'),
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
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSection(
              icon: Icons.info_outline,
              title: 'Project Information',
              children: [
                _buildInfoRow(
                    Icons.category, 'Type', 'Safe Drive Alert System'),
                _buildInfoRow(Icons.memory, 'Hardware',
                    'ESP32, GPS, Flame, MQ-2, MPU6050'),
                _buildInfoRow(Icons.code, 'Tech Stack',
                    'Flutter · Firebase · ESP32 · React'),
                _buildInfoRow(Icons.cloud, 'Backend', 'Firestore (real-time)'),
                _buildInfoRow(
                    Icons.article, 'Standard', 'IEEE Paper Published'),
              ],
            ),
            const SizedBox(height: 16),

            _buildSection(
              icon: Icons.support_agent,
              title: 'Bus Helpline',
              children: [
                _buildActionButton(
                  Icons.phone,
                  'Call Helpline',
                  '1800-XXX-XXXX (toll free)',
                  AppTheme.safeColor,
                  () => _launchPhone('1800XXXXXXX'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSection(
              icon: Icons.help_outline,
              title: 'Support',
              children: [
                _buildActionButton(
                  Icons.bug_report,
                  'Report an Issue',
                  'Found a bug? Let us know',
                  AppTheme.dangerColor,
                  () => _launchEmail('bus.alert.track@gmail.com'),
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  Icons.feedback_outlined,
                  'Send Feedback',
                  'We appreciate your feedback',
                  AppTheme.primaryColor,
                  () => _launchUrl('https://forms.gle/XbQZQB7k8y177mLf8'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSection(
              icon: Icons.link,
              title: 'Links',
              children: [
                _buildLinkButton(
                  Icons.code,
                  'GitHub Repository',
                  () => _launchUrl('https://github.com/yourusername/safetrack'),
                ),
                _buildLinkButton(
                  Icons.language,
                  'Project Website',
                  () => _launchUrl('https://safetrack.example.com'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              '© 2026 SafeTrack — Aditya University ECE',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.grey[300], fontSize: 11),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textLight),
            const SizedBox(width: 12),
            Text(
              '$label: ',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: onTap != null
                      ? AppTheme.primaryColor
                      : AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkButton(IconData icon, String title, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.textLight),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(Icons.open_in_new,
                  size: 14, color: AppTheme.textLight),
            ],
          ),
        ),
      ),
    );
  }
}
