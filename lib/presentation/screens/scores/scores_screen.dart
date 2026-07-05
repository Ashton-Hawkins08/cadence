import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/providers/score_provider.dart';
import 'score_folder_screen.dart';

// ── Scores: piece folder dashboard ────────────────────────────────────────────
//
// Folders ("Symphony No. 9") hold imported sheet images. Each folder can be
// linked to a saved Piece Profile whose section roadmap drives the metronome
// and the auto page turner inside the rehearsal canvas.

class ScoresScreen extends ConsumerWidget {
  const ScoresScreen({super.key});

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    final name = await _promptName(context, title: 'New Piece Folder');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(scoreRepositoryProvider).createFolder(name.trim());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final folders = ref.watch(scoreFoldersProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Scores',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'New piece folder',
            onPressed: () => _createFolder(context, ref),
          ),
        ],
      ),
      body: folders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.library_music_outlined,
                          size: 48,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'Create a piece folder, then import photos of your '
                        'sheet music to rehearse with the metronome.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) =>
                    _FolderTile(folder: list[i], isDark: isDark),
              ),
      ),
    );
  }
}

// ── Folder tile ───────────────────────────────────────────────────────────────

class _FolderTile extends ConsumerWidget {
  final ScoreFolder folder;
  final bool isDark;
  const _FolderTile({required this.folder, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pages = ref.watch(scorePagesProvider(folder.id)).valueOrNull ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Icon(Icons.folder_special_outlined,
            color: AppColors.indigoNavySoft, size: 28),
        title: Text(folder.name,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Row(
          children: [
            Text('${pages.length} page${pages.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                )),
            if (folder.linkedPieceId != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.streakGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('piece linked',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.streakGold
                          : const Color(0xFF8A6D00),
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            final repo = ref.read(scoreRepositoryProvider);
            switch (v) {
              case 'rename':
                final name = await _promptName(context,
                    title: 'Rename Folder', initial: folder.name);
                if (name != null && name.trim().isNotEmpty) {
                  await repo.renameFolder(folder.id, name.trim());
                }
              case 'link':
                if (context.mounted) {
                  await _pickLinkedPiece(context, ref, folder);
                }
              case 'delete':
                if (context.mounted) {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete folder?'),
                      content: Text(
                          '"${folder.name}" and all its pages and annotations '
                          'will be permanently deleted.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('Delete',
                                style:
                                    TextStyle(color: AppColors.error))),
                      ],
                    ),
                  );
                  if (ok == true) await repo.deleteFolder(folder.id);
                }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'link', child: Text('Link piece profile')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScoreFolderScreen(folder: folder),
          ),
        ),
      ),
    );
  }
}

// ── Piece link picker ─────────────────────────────────────────────────────────

Future<void> _pickLinkedPiece(
    BuildContext context, WidgetRef ref, ScoreFolder folder) async {
  final pieces = await ref.read(pieceRepositoryProvider).watchAll().first;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Link a Piece Profile',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (pieces.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Text(
                    'No saved pieces yet. Build one in Metronome → Pieces '
                    'first — its tempo roadmap will then drive this score.'),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (folder.linkedPieceId != null)
                    ListTile(
                      leading: const Icon(Icons.link_off),
                      title: const Text('Unlink current piece'),
                      onTap: () async {
                        await ref
                            .read(scoreRepositoryProvider)
                            .setLinkedPiece(folder.id, null);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ...pieces.map((p) => ListTile(
                        leading: Icon(
                          p.id == folder.linkedPieceId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: AppColors.indigoNavySoft,
                        ),
                        title: Text(p.title),
                        onTap: () async {
                          await ref
                              .read(scoreRepositoryProvider)
                              .setLinkedPiece(folder.id, p.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

// ── Shared name prompt ────────────────────────────────────────────────────────

Future<String?> _promptName(BuildContext context,
    {required String title, String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(hintText: 'Name'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save')),
      ],
    ),
  );
}
