import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sakan/core/theme/app_colors.dart';
import 'package:sakan/core/theme/app_radius.dart';
import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/shared/models/current_family_context.dart';
import 'package:sakan/shared/widgets/branding/sakan_brand.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final Future<CurrentFamilyContext> _familyContext;

  @override
  void initState() {
    super.initState();
    _familyContext = AppDependencies.currentFamilyService.load();
  }

  void _openBranch(int branchIndex) {
    widget.navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          ColoredBox(
            color: AppColors.background,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 7, 16, 5),
                child: const Center(child: SakanWordmark(height: 32)),
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: widget.navigationShell,
            ),
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<CurrentFamilyContext>(
        future: _familyContext,
        builder: (context, snapshot) {
          if (snapshot.data?.canUseAi != true) return const SizedBox.shrink();
          return IconButton(
            tooltip: 'Ask Sakan',
            onPressed: () {
              context.pushNamed('askSakan');
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: 72,
              height: 72,
            ),
            icon: const SakanAssistantIcon(size: 68),
          );
        },
      ),
      bottomNavigationBar: _SakanBottomNavigation(
        currentBranchIndex: widget.navigationShell.currentIndex,
        onSelected: _openBranch,
      ),
    );
  }
}

class _SakanBottomNavigation extends StatelessWidget {
  const _SakanBottomNavigation({
    required this.currentBranchIndex,
    required this.onSelected,
  });

  final int currentBranchIndex;
  final ValueChanged<int> onSelected;

  static const _items = <_SakanNavItemData>[
    _SakanNavItemData(
      branchIndex: 0,
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _SakanNavItemData(
      branchIndex: 3,
      label: 'Calendar',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
    ),
    _SakanNavItemData(branchIndex: 1, label: 'Twin', isAi: true),
    _SakanNavItemData(
      branchIndex: 2,
      label: 'Moments',
      icon: Icons.layers_outlined,
      selectedIcon: Icons.layers,
    ),
    _SakanNavItemData(
      branchIndex: 4,
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SizedBox(
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                color: AppColors.surface,
                elevation: 9,
                shadowColor: Colors.black.withAlpha(34),
                borderRadius: BorderRadius.circular(AppRadius.navigation),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.navigation),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: _items
                        .map((item) {
                          final selected =
                              currentBranchIndex == item.branchIndex;

                          return Expanded(
                            child: _SakanNavButton(
                              item: item,
                              selected: selected,
                              onTap: () {
                                onSelected(item.branchIndex);
                              },
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Semantics(
                  button: true,
                  selected: currentBranchIndex == 1,
                  label: 'Digital Twin',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      onSelected(1);
                    },
                    child: SakanAiStar(
                      size: 68,
                      selected: currentBranchIndex == 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SakanNavButton extends StatelessWidget {
  const _SakanNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _SakanNavItemData item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.isAi ? 'Digital Twin' : item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.navigation),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(3, item.isAi ? 41 : 8, 3, 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!item.isAi) ...[
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 25,
                  color: color,
                ),
                const SizedBox(height: 3),
              ],
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SakanNavItemData {
  const _SakanNavItemData({
    required this.branchIndex,
    required this.label,
    this.icon,
    this.selectedIcon,
    this.isAi = false,
  });

  final int branchIndex;
  final String label;
  final IconData? icon;
  final IconData? selectedIcon;
  final bool isAi;
}
