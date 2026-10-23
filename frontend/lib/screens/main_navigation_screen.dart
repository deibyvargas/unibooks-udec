import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import 'admin/admin_dashboard_screen.dart';
import 'catalog/catalog_screen.dart';
import 'trades/trades_screen.dart';
import 'chat/chat_list_screen.dart';
import 'publications/create_publication_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    const CatalogScreen(),
    const TradesScreen(),
    const ChatListScreen(),
    CreatePublicationScreen(
      onPublishedSuccess: () => setState(() => _currentIndex = 0),
    ),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final unreadCount = chatProvider.totalNoLeidos;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        if (isWide) {
          // Layout Responsivo para Web y Pantallas Anchas
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (val) => setState(() => _currentIndex = val),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: const [
                        Icon(Icons.school_rounded, color: AppColors.primary, size: 36),
                        SizedBox(height: 4),
                        Text(
                          'UNIBOOKS',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  destinations: [
                    const NavigationRailDestination(
                      icon: Icon(Icons.menu_book_outlined),
                      selectedIcon: Icon(Icons.menu_book_rounded, color: AppColors.primary),
                      label: Text('Catálogo'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.swap_horiz_outlined),
                      selectedIcon: Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                      label: Text('Trueques'),
                    ),
                    NavigationRailDestination(
                      icon: Badge(
                        isLabelVisible: unreadCount > 0,
                        label: Text('$unreadCount'),
                        child: const Icon(Icons.chat_bubble_outline_rounded),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: unreadCount > 0,
                        label: Text('$unreadCount'),
                        child: const Icon(Icons.chat_bubble_rounded, color: AppColors.primary),
                      ),
                      label: const Text('Mensajes'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.add_circle_outline_rounded),
                      selectedIcon: Icon(Icons.add_circle_rounded, color: AppColors.primary),
                      label: Text('Publicar'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
                      label: Text('Perfil'),
                    ),
                  ],
                  trailing: context.watch<AuthProvider>().currentUser?.isAdmin == true
                      ? Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: IconButton(
                                icon: const Icon(Icons.security_rounded, color: Colors.amber, size: 28),
                                tooltip: 'Panel de Control Administrativo (RBAC)',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                const VerticalDivider(thickness: 1, width: 1, color: AppColors.cardBorder),
                Expanded(child: _screens[_currentIndex]),
              ],
            ),
          );
        }

        // Layout para Móvil (Android)
        return Scaffold(
          body: _screens[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (val) => setState(() => _currentIndex = val),
            indicatorColor: AppColors.primary.withOpacity(0.15),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book_rounded, color: AppColors.primary),
                label: 'Catálogo',
              ),
              const NavigationDestination(
                icon: Icon(Icons.swap_horiz_outlined),
                selectedIcon: Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                label: 'Trueques',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                selectedIcon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  child: const Icon(Icons.chat_bubble_rounded, color: AppColors.primary),
                ),
                label: 'Mensajes',
              ),
              const NavigationDestination(
                icon: Icon(Icons.add_circle_outline_rounded),
                selectedIcon: Icon(Icons.add_circle_rounded, color: AppColors.primary),
                label: 'Publicar',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }
}
