import 'package:flutter/material.dart';
import '../config/theme.dart';

class SafeTrackBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const SafeTrackBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.directions_bus_rounded, 'Buses'),
              _buildNavItem(2, Icons.auto_awesome_rounded, 'AI', isAi: true),
              _buildNavItem(3, Icons.contact_support_rounded, 'Contact'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label,
      {bool isAi = false}) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: isSelected && isAi
              ? const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                )
              : null,
          color: isSelected && !isAi
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? (isAi ? Colors.white : AppTheme.primaryColor)
                  : Colors.grey.shade600,
              size: isAi ? 24 : 22,
            ),
            if (isSelected || isAi) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? (isAi ? Colors.white : AppTheme.primaryColor)
                      : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
