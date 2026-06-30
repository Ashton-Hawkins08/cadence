import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/providers/piece_provider.dart';

class PieceArchiveScreen extends ConsumerWidget {
  const PieceArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final archivedAsync = ref.watch(archivedPiecesProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        title: Text('Piece Archive',
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: archivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (pieces) => pieces.isEmpty
            ? _EmptyArchive(theme: theme)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: pieces.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _ArchivedPieceTile(
                  piece: pieces[i],
                  isDark: isDark,
                  theme: theme,
                ),
              ),
      ),
    );
  }
}

// ── Archived piece tile ───────────────────────────────────────────────────────

class _ArchivedPieceTile extends ConsumerWidget {
  final MetronomePiece piece;
  final bool isDark;
  final ThemeData theme;

  const _ArchivedPieceTile(
      {required this.piece, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(pieceSectionsProvider(piece.id));
    final sectionCount = sectionsAsync.valueOrNull?.length ?? 0;

    return Card(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.indigoNavy.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.archive_outlined,
              color: AppColors.indigoNavySoft, size: 22),
        ),
        title: Text(piece.title,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '$sectionCount section${sectionCount == 1 ? '' : 's'}',
          style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Restore
            IconButton(
              icon: const Icon(Icons.unarchive_outlined,
                  color: AppColors.indigoNavySoft),
              tooltip: 'Restore',
              onPressed: () async {
                await ref.read(pieceRepositoryProvider).restore(piece.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('"${piece.title}" restored.')));
                }
              },
            ),
            // Delete permanently
            IconButton(
              icon: Icon(Icons.delete_forever_outlined,
                  color: AppColors.error),
              tooltip: 'Delete permanently',
              onPressed: () async {
                final confirm = await _confirmDelete(context, piece.title);
                if (confirm == true && context.mounted) {
                  await ref.read(pieceRepositoryProvider).delete(piece.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyArchive extends StatelessWidget {
  final ThemeData theme;
  const _EmptyArchive({required this.theme});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.archive_outlined,
                size: 56, color: AppColors.indigoNavySoft),
            const SizedBox(height: 16),
            Text('Piece archive is empty',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Archived pieces appear here.',
                style: theme.textTheme.bodyMedium),
          ],
        ),
      );
}

Future<bool?> _confirmDelete(BuildContext context, String title) =>
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: Text('"$title" will be gone forever.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
