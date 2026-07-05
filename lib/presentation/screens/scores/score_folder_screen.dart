import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/presentation/providers/score_provider.dart';
import 'score_viewer_screen.dart';

// ── Folder detail: import + manage score pages ────────────────────────────────

class ScoreFolderScreen extends ConsumerStatefulWidget {
  final ScoreFolder folder;
  const ScoreFolderScreen({super.key, required this.folder});

  @override
  ConsumerState<ScoreFolderScreen> createState() => _ScoreFolderScreenState();
}

class _ScoreFolderScreenState extends ConsumerState<ScoreFolderScreen> {
  final _picker = ImagePicker();
  bool _importing = false;

  Future<void> _importImages() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Import from gallery / files'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            // Camera capture only exists on mobile.
            if (Platform.isAndroid || Platform.isIOS)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Capture with camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _importing = true);
    try {
      final repo = ref.read(scoreRepositoryProvider);
      final existing = await repo.getPages(widget.folder.id);
      var nextNum = existing.length + 1;

      if (source == ImageSource.gallery) {
        final files = await _picker.pickMultiImage();
        for (final f in files) {
          await repo.addPage(
            folderId: widget.folder.id,
            sourcePath: f.path,
            name: 'Page $nextNum',
          );
          nextNum++;
        }
      } else {
        final shot = await _picker.pickImage(source: ImageSource.camera);
        if (shot != null) {
          await repo.addPage(
            folderId: widget.folder.id,
            sourcePath: shot.path,
            name: 'Page $nextNum',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _renamePage(ScorePage page) async {
    final controller = TextEditingController(text: page.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Page'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration:
              const InputDecoration(hintText: 'e.g. Intro Sheet, Letter C'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(scoreRepositoryProvider).renamePage(page.id, name.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pages = ref.watch(scorePagesProvider(widget.folder.id));

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(widget.folder.name,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _importImages,
        backgroundColor: AppColors.indigoNavy,
        foregroundColor: Colors.white,
        icon: _importing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add_photo_alternate_outlined),
        label: Text(_importing ? 'Importing…' : 'Import'),
      ),
      body: pages.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => Column(
          children: [
            if (list.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.indigoNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Open Rehearsal Canvas'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScoreViewerScreen(
                          folder: widget.folder,
                          initialPage: 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        'No pages yet — import photos of your score.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: list.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        final ids = list.map((p) => p.id).toList();
                        final moved = ids.removeAt(oldIndex);
                        ids.insert(newIndex, moved);
                        ref
                            .read(scoreRepositoryProvider)
                            .reorderPages(widget.folder.id, ids);
                      },
                      itemBuilder: (_, i) {
                        final page = list[i];
                        return Container(
                          key: ValueKey(page.id),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(page.imagePath),
                                width: 44,
                                height: 56,
                                fit: BoxFit.cover,
                                cacheWidth: 96,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 44,
                                  height: 56,
                                  color: AppColors.error
                                      .withValues(alpha: 0.15),
                                  child: const Icon(Icons.broken_image,
                                      size: 20),
                                ),
                              ),
                            ),
                            title: Text('${i + 1} · ${page.name}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600)),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                switch (v) {
                                  case 'rename':
                                    await _renamePage(page);
                                  case 'delete':
                                    await ref
                                        .read(scoreRepositoryProvider)
                                        .deletePage(page.id);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'rename', child: Text('Rename')),
                                PopupMenuItem(
                                    value: 'delete', child: Text('Delete')),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScoreViewerScreen(
                                  folder: widget.folder,
                                  initialPage: i,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
