import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/presentation/providers/metronome_provider.dart';
import 'standard_metronome_screen.dart';
import 'piece_builder/piece_list_screen.dart';

// Which tab is active inside the metronome module
enum _MetronomeTab { standard, pieceBuilder }

class MetronomeShell extends ConsumerStatefulWidget {
  const MetronomeShell({super.key});

  @override
  ConsumerState<MetronomeShell> createState() => _MetronomeShellState();
}

class _MetronomeShellState extends ConsumerState<MetronomeShell> {
  _MetronomeTab _tab = _MetronomeTab.standard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final navBg =
        isDark ? AppColors.darkNavBar : AppColors.lightNavBar;
    final activeColor = AppColors.indigoNavySoft;
    final inactiveColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: const [
          StandardMetronomeScreen(),
          PieceListScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 64,
        color: navBg,
        child: Row(
          children: [
            // Left — Standard
            Expanded(
              child: _NavButton(
                icon: Icons.av_timer,
                label: 'Standard',
                active: _tab == _MetronomeTab.standard,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => setState(() => _tab = _MetronomeTab.standard),
              ),
            ),

            // Center — Cadence logo → exits metronome
            GestureDetector(
              onTap: _exitMetronome,
              child: SizedBox(
                width: 64,
                height: 64,
                child: Center(
                  child: Image.asset(
                    isDark
                        ? 'assets/images/logo_dark_symbol.png'
                        : 'assets/images/logo_light_symbol.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // Right — Piece Builder
            Expanded(
              child: _NavButton(
                icon: Icons.queue_music,
                label: 'Pieces',
                active: _tab == _MetronomeTab.pieceBuilder,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () =>
                    setState(() => _tab = _MetronomeTab.pieceBuilder),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exitMetronome() {
    // Stop the metronome before leaving
    ref.read(metronomeEngineProvider).stop();
    Navigator.of(context).pop();
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}
