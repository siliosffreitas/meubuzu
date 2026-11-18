import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routing/app_routes.dart';
import 'widgets/account/account_tab.dart';
import 'widgets/favorites/favorites_tab.dart';
import 'widgets/map/map_tab.dart';

/// Tela principal com as abas Mapa, Favoritos e Conta.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialTabIndex = AppRoutes.homeTabMap});

  /// Aba exibida ao abrir a Home.
  final int initialTabIndex;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex = _normalizeTabIndex(widget.initialTabIndex);

  static int _normalizeTabIndex(int index) {
    if (index < AppRoutes.homeTabMap || index > AppRoutes.homeTabAccount) {
      return AppRoutes.homeTabMap;
    }
    return index;
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      _selectedIndex = _normalizeTabIndex(widget.initialTabIndex);
    }
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            const MapTab(),
            FavoritesTab(
              isSelected: _selectedIndex == 1,
              onExplore: () => _selectTab(0),
            ),
            const AccountTab(),
          ],
        ),
        bottomNavigationBar: _HomeNavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
        ),
      ),
    );
  }
}

class _HomeNavigationBar extends StatelessWidget {
  const _HomeNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.6)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          height: 68,
          indicatorColor: AppColors.surface,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 24,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Icon(Icons.star_outline_rounded),
              selectedIcon: Icon(Icons.star_rounded),
              label: 'Favoritos',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Conta',
            ),
          ],
        ),
      ),
    );
  }
}
