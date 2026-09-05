import 'package:flutter/material.dart';
import '../services/auth_service.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded,      label: 'Home'),
    _NavItem(icon: Icons.people_alt_rounded,      label: 'Members'),
    _NavItem(icon: Icons.person_add_alt_1_rounded, label: 'Leads'),
    _NavItem(icon: Icons.restaurant_menu_rounded,  label: 'Diet Plans'),
    _NavItem(icon: Icons.card_membership_rounded,  label: 'Membership Plans'),
    _NavItem(icon: Icons.bar_chart_rounded,        label: 'Reports'),
    _NavItem(icon: Icons.settings_rounded,         label: 'Settings'),
    _NavItem(icon: Icons.verified_rounded,         label: 'Subscription'),
  ];

  late final List<Widget> _screens = [
    DashboardScreen(
      onNavigateTab: (idx) => setState(() => _currentIndex = idx),
      onAddMember: () => setState(() => _currentIndex = 1),
    ),
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
    _scaffoldKey.currentState?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor   = isDark ? const Color(0xFF08101C) : Colors.white;
    final pageBgColor  = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final txtPrimary   = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtSecondary = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);
    final borderColor  = isDark ? const Color(0xFF1B263B) : const Color(0xFFE2E8F0);
    const activeCyan   = Color(0xFF00E5C0);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: pageBgColor,
      appBar: AppBar(
        backgroundColor: navBgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, size: 24, color: txtPrimary),
          tooltip: 'Menu',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        titleSpacing: 0,
        centerTitle: false,
        title: Text(
          _navItems[_currentIndex].label,
          style: TextStyle(
            color: txtPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          // Pro Plan Gold Badge
          GestureDetector(
            onTap: () => setState(() => _currentIndex = 7),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF382904) : const Color(0xFFFEF08A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEAB308), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: Color(0xFFCA8A04), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'PRO',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFEAB308) : const Color(0xFF854D0E),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_none_rounded, size: 24, color: txtPrimary),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 6),
        ],
      ),

      // ── Drawer (Theme Adaptive) ──
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.82,
        backgroundColor: navBgColor,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header (Logo + Title + Subtitle + Close Button) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Fit',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: txtPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: 'nex',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: activeCyan,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Gym Management Pro',
                              style: TextStyle(
                                color: txtSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: txtSecondary, size: 22),
                      onPressed: () => _scaffoldKey.currentState?.closeDrawer(),
                    ),
                  ],
                ),
              ),

              // ── Menu Items ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    _drawerItem(context, Icons.home_rounded, 'Home', 0, isDark, txtPrimary, txtSecondary),
                    _drawerItem(context, Icons.groups_rounded, 'Members', 1, isDark, txtPrimary, txtSecondary),
                    _drawerItem(context, Icons.person_add_rounded, 'Leads / Inquiries', 2, isDark, txtPrimary, txtSecondary),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: borderColor),
                    ),
                    const SizedBox(height: 6),
                    _drawerSection('MANAGEMENT', txtSecondary),
                    _drawerItem(context, Icons.restaurant_rounded, 'Diet Plans', 3, isDark, txtPrimary, txtSecondary),
                    _drawerItem(context, Icons.card_membership_rounded, 'Membership Plans', 4, isDark, txtPrimary, txtSecondary),
                    _drawerItem(context, Icons.bar_chart_rounded, 'Reports', 5, isDark, txtPrimary, txtSecondary),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: borderColor),
                    ),
                    const SizedBox(height: 6),
                    _drawerSection('ACCOUNT', txtSecondary),
                    _drawerItem(context, Icons.settings_rounded, 'Settings', 6, isDark, txtPrimary, txtSecondary),
                    _drawerItem(context, Icons.credit_card_rounded, 'Subscription & Billing', 7, isDark, txtPrimary, txtSecondary),
                    _drawerActionItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      txtPrimary: txtPrimary,
                      txtSecondary: txtSecondary,
                      onTap: _showHelpSupportDialog,
                    ),
                    _drawerActionItem(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      txtPrimary: txtPrimary,
                      txtSecondary: txtSecondary,
                      onTap: () async {
                        _scaffoldKey.currentState?.closeDrawer();
                        await AuthService.signOut();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // ── Footer ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, color: borderColor),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fitnex v1.0',
                      style: TextStyle(
                        color: txtSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gym Management Pro',
                      style: TextStyle(
                        color: txtSecondary.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // ── Bottom Navigation Bar (Theme Adaptive) ──
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBgColor,
          border: Border(top: BorderSide(color: borderColor, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _bottomNavItem(index: 0, label: 'Home', icon: Icons.home_rounded, isDark: isDark, txtSecondary: txtSecondary),
                _bottomNavItem(index: 1, label: 'Members', icon: Icons.groups_rounded, isDark: isDark, txtSecondary: txtSecondary),
                _bottomNavItem(index: 4, label: 'Plans', icon: Icons.card_membership_rounded, isDark: isDark, txtSecondary: txtSecondary),
                _bottomNavItem(index: 3, label: 'Diet', icon: Icons.restaurant_menu_rounded, isDark: isDark, txtSecondary: txtSecondary),
                _bottomNavItem(index: 2, label: 'Leads', icon: Icons.person_add_rounded, isDark: isDark, txtSecondary: txtSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHelpSupportDialog() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131929),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: Color(0xFF00E5C0)),
            SizedBox(width: 10),
            Text('Help & Support', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need assistance with your Fitnex account?', style: TextStyle(color: Color(0xFF8896B3), fontSize: 14)),
            SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.email_outlined, color: Color(0xFF00E5C0), size: 18),
                SizedBox(width: 8),
                Text('support@fitnex.com', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone_outlined, color: Color(0xFF00E5C0), size: 18),
                SizedBox(width: 8),
                Text('+91 98765 43210', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF00E5C0), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _drawerSection(String label, Color txtSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          color: txtSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    int index,
    bool isDark,
    Color txtPrimary,
    Color txtSecondary,
  ) {
    final selected = _currentIndex == index;
    const activeTeal = Color(0xFF00E5C0);
    final activeBg = isDark ? const Color(0xFF0C2B30) : const Color(0xFFE6F9F5);
    final iconBoxBg = selected
        ? activeTeal.withValues(alpha: isDark ? 0.15 : 0.1)
        : (isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onMenuSelected(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: selected ? Border.all(color: activeTeal.withValues(alpha: 0.3)) : null,
            ),
            child: Row(
              children: [
                if (selected)
                  Container(
                    width: 4,
                    height: 24,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: activeTeal,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconBoxBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: selected ? activeTeal : txtSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: selected ? (isDark ? Colors.white : const Color(0xFF0F172A)) : txtPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.circle,
                    size: 6,
                    color: activeTeal,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerActionItem({
    required IconData icon,
    required String title,
    required Color txtPrimary,
    required Color txtSecondary,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: txtSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: txtSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: TextStyle(
                    color: txtPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem({
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color txtSecondary,
  }) {
    final isSelected = _currentIndex == index;
    const activeCyan = Color(0xFF00E5C0);

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeCyan : txtSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeCyan : txtSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 18 : 0,
              decoration: BoxDecoration(
                color: activeCyan,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
