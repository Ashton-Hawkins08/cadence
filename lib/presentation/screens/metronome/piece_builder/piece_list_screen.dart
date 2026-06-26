import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/data/repositories/piece_repository.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/providers/piece_provider.dart';
import 'piece_editor_screen.dart';
import 'piece_player_screen.dart';
import 'piece_archive_screen.dart';

class PieceListScreen extends ConsumerWidget {
  const PieceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final piecesAsync = ref.watch(allPiecesProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.archive_outlined),
          tooltip: 'Piece Archive',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PieceArchiveScreen()),
          ),
        ),
        title: Text('Pieces',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createPiece(context, ref),
          ),
        ],
      ),
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: piecesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (pieces) => pieces.isEmpty
            ? _EmptyState(onAdd: () => _createPiece(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: pieces.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _PieceTile(
                  piece: pieces[i],
                  isDark: isDark,
                  theme: theme,
                ),
              ),
      ),
    );
  }

  Future<void> _createPiece(BuildContext context, WidgetRef ref) async {
    final name = await _showNameDialog(context, 'New Piece', '');
    if (name == null || name.isEmpty || !context.mounted) return;
    final repo = ref.read(pieceRepositoryProvider);
    final id = await repo.create(name);
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PieceEditorScreen(pieceId: id, title: name)));
  }
}

// ── Piece tile ────────────────────────────────────────────────────────────────

class _PieceTile extends ConsumerWidget {
  final MetronomePiece piece;
  final bool isDark;
  final ThemeData theme;

  const _PieceTile(
      {required this.piece, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionAsync = ref.watch(pieceSectionsProvider(piece.id));
    final sectionCount = sectionAsync.valueOrNull?.length ?? 0;

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
          child: const Icon(Icons.queue_music,
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
            IconButton(
              icon: const Icon(Icons.play_circle_fill,
                  color: AppColors.indigoNavySoft),
              iconSize: 32,
              onPressed: sectionCount == 0 ? null : () => _play(context),
            ),
            IconButton(
              icon: Icon(Icons.more_vert,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
              onPressed: () => _showOptions(context, ref),
            ),
          ],
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                PieceEditorScreen(pieceId: piece.id, title: piece.title))),
      ),
    );
  }

  void _play(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            PiecePlayerScreen(pieceId: piece.id, title: piece.title)));
  }

  Future<void> _showOptions(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(pieceRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PieceOptions(
        piece: piece,
        repo: repo,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

// ── Piece options sheet ───────────────────────────────────────────────────────

class _PieceOptions extends ConsumerWidget {
  final MetronomePiece piece;
  final PieceRepository repo;
  final VoidCallback onClose;

  const _PieceOptions(
      {required this.piece, required this.repo, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () async {
                onClose();
                final name =
                    await _showNameDialog(context, 'Rename Piece', piece.title);
                if (name != null && name.isNotEmpty) {
                  await repo.rename(piece.id, name);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate'),
              onTap: () async {
                onClose();
                await repo.duplicate(piece.id, '${piece.title} Copy');
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              onTap: () async {
                onClose();
                await repo.archive(piece.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('"${piece.title}" archived.')));
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Delete',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: AppColors.error)),
              onTap: () async {
                onClose();
                final confirm = await _showDeleteConfirm(context, piece.title);
                if (confirm == true) await repo.delete(piece.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.queue_music,
              size: 56, color: AppColors.indigoNavySoft),
          const SizedBox(height: 16),
          Text('No pieces yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Tap + to build your first piece.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('New Piece'),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.indigoNavy),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<String?> _showNameDialog(
    BuildContext context, String title, String initial) async {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Name'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Save')),
      ],
    ),
  );
}

Future<bool?> _showDeleteConfirm(BuildContext context, String title) =>
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Piece?'),
        content: Text('Delete "$title"? This cannot be undone.'),
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
