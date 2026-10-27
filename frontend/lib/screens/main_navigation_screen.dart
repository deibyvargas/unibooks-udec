import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/chat_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final unreadCount = chatProvider.totalNoLeidos;
    final bool isWide = MediaQuery.sizeOf(context).width >= 800;

    // Lista de pantallas dinámica según el rol
    final List<Widget> screens = [
      const CatalogScreen(),
      const TradesScreen(),
      const ChatListScreen(),
      CreatePublicationScreen(
        onPublishedSuccess: () => setState(() => _currentIndex = 0),
      ),
      const ProfileScreen(),
    ];

    // Asegurar que el índice actual no exceda el rango
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isWide) {
          // Layout Responsivo para Web y Pantallas Anchas
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: safeIndex,
                  onDestinationSelected: (val) =>
                      setState(() => _currentIndex = val),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: const [
                        Icon(
                          Icons.school_rounded,
                          color: AppColors.primary,
                          size: 36,
                        ),
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
                      selectedIcon: Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primary,
                      ),
                      label: Text('Catálogo'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.swap_horiz_outlined),
                      selectedIcon: Icon(
                        Icons.swap_horiz_rounded,
                        color: AppColors.primary,
                      ),
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
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      label: const Text('Mensajes'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.add_circle_outline_rounded),
                      selectedIcon: Icon(
                        Icons.add_circle_rounded,
                        color: AppColors.primary,
                      ),
                      label: Text('Publicar'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                      ),
                      label: Text('Perfil'),
                    ),
                  ],
                ),
                const VerticalDivider(
                  thickness: 1,
                  width: 1,
                  color: AppColors.cardBorder,
                ),
                Expanded(child: screens[safeIndex]),
              ],
            ),
          );
        }

        // Layout para Móvil (Android APK)
        return Scaffold(
          body: screens[safeIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (val) => setState(() => _currentIndex = val),
            indicatorColor: AppColors.primary.withOpacity(0.15),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.primary,
                ),
                label: 'Catálogo',
              ),
              const NavigationDestination(
                icon: Icon(Icons.swap_horiz_outlined),
                selectedIcon: Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.primary,
                ),
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
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: AppColors.primary,
                  ),
                ),
                label: 'Mensajes',
              ),
              const NavigationDestination(
                icon: Icon(Icons.add_circle_outline_rounded),
                selectedIcon: Icon(
                  Icons.add_circle_rounded,
                  color: AppColors.primary,
                ),
                label: 'Publicar',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                ),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }
}
