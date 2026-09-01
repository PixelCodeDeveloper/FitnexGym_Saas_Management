import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'members_screen.dart';
import 'leads_screen.dart';
import 'diet_screen.dart';
import 'plans_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<String> _titles = [
    'Dashboard',
    'Members',
    'Sales Pipeline',
    'Diet Plans',
    'Subscription Plans',
    'Reports',
    'Settings',
    'Subscription & Billing',
  ];

  final List<Widget> _screens = [
    const DashboardScreen(),
    const MembersScreen(),
    const LeadsScreen(),
    const DietScreen(),
    const PlansScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
    const SubscriptionScreen(),
  ];

  void _onMenuSelected(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _currentIndex = 7),
            icon: const Icon(Icons.star_rounded, color: AppTheme.warning, size: 18),
            label: const Text(
              'Pro Plan',
              style: TextStyle(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 22,
                color: AppTheme.textPrimary,
              ),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // ── Drawer Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Text(
                        'OG',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Owner Gym',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _onMenuSelected(7),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: AppTheme.success, size: 8),
                          SizedBox(width: 6),
                          Text(
                            'Active Plan • View Details →',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Menu Items ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(Icons.dashboard_rounded, 'Home', 0),
                  _buildDrawerItem(Icons.people_alt_rounded, 'Members', 1),
                  _buildDrawerItem(
                    Icons.person_add_alt_1_rounded,
                    'Leads / Inquiries',
                    2,
                  ),
                  _buildDrawerItem(
                    Icons.restaurant_menu_rounded,
                    'Diet Plans',
                    3,
                  ),
                  _buildDrawerItem(
                    Icons.card_membership_rounded,
                    'Manage Plans',
                    4,
                  ),
                  _buildDrawerItem(Icons.bar_chart_rounded, 'Reports', 5),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(height: 1),
                  ),
                  _buildDrawerItem(Icons.settings_rounded, 'Settings', 6),
                  _buildDrawerItem(
                    Icons.verified_rounded,
                    'Subscription & Billing',
                    7,
                  ),
                ],
              ),
            ),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: const Text(
                'Gym SaaS v1.0',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      body: _screens[_currentIndex],
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    final selected = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          color: selected ? AppTheme.primary : AppTheme.textSecondary,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? AppTheme.primary : AppTheme.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        selected: selected,
        selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
        onTap: () => _onMenuSelected(index),
      ),
    );
  }
}
