import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/theme/app_colors.dart';
import 'package:cadence/data/database/app_database.dart';
import 'package:cadence/presentation/providers/categories_provider.dart';
import 'package:cadence/presentation/providers/database_provider.dart';
import 'package:cadence/presentation/providers/exercises_provider.dart';
import 'package:cadence/presentation/providers/piece_provider.dart';
import 'package:cadence/presentation/providers/score_provider.dart';
import 'package:cadence/presentation/screens/metronome/piece_builder/piece_editor_screen.dart';
import 'package:cadence/presentation/screens/metronome/piece_builder/piece_player_screen.dart';
import 'score_folder_screen.dart';
import 'score_viewer_screen.dart';

// ── Scores & Pieces browser ───────────────────────────────────────────────────
//
// Scores (sheet music) and pieces (measure-tracking maps) always belong to an
// EXERCISE. This screen is a browser, not a factory: it lists categories →
// exercises with their link status, and everything it creates is attached to
// the exercise you tapped. Brand-new attachments are made in Manage →
// Categories & Exercises → Add Exercise.
//
// Badge logic: score linked · piece linked · score and piece linked.

class ScoresPiecesScreen extends ConsumerWidget {
  const ScoresPiecesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final exercisesAsync = ref.watch(exercisesProvider);
    final folders = ref.watch(scoreFoldersProvider).valueOrNull ?? [];
    final pieces = ref.watch(allPiecesProvider).valueOrNull ?? [];

    // exerciseId → attachment lookups (one score + one piece per exercise)
    final folderByExercise = <int, ScoreFolder>{
      for (final f in folders)
        if (f.exerciseId != null) f.exerciseId!: f,
    };
    final pieceByExercise = <int, MetronomePiece>{
      for (final p in pieces)
        if (p.exerciseId != null) p.exerciseId!: p,
    };
    // Standalone/orphaned items: created before scores & pieces became
    // exercise-owned, OR attached to an exercise that was since archived or
    // deleted. Keeping them visible here means nothing silently disappears.
    final liveExerciseIds = (exercisesAsync.valueOrNull ?? [])
        .map((e) => e.id)
        .toSet();
    final unlinkedFolders = folders
        .where(
          (f) =>
              f.exerciseId == null || !liveExerciseIds.contains(f.exerciseId),
        )
        .toList();
    final unlinkedPieces = pieces
        .where(
          (p) =>
              p.exerciseId == null || !liveExerciseIds.contains(p.exerciseId),
        )
        .toList();

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Scores & Pieces',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        elevation: 0,
      ),
      body: exercisesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (exercises) {
          if (exercises.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Scores and pieces live on your exercises.\n\n'
                  'Create one in Manage → Categories & Exercises → '
                  'Add Exercise, and switch on "Attach Sheet Music" or '
                  '"Measure Tracking".',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            );
          }

          final uncategorized = exercises
              .where((e) => e.categoryId == null)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              for (final c in categories)
                _CategoryGroup(
                  title: c.name,
                  exercises: exercises
                      .where((e) => e.categoryId == c.id)
                      .toList(),
                  folderByExercise: folderByExercise,
                  pieceByExercise: pieceByExercise,
                  isDark: isDark,
                ),
              if (uncategorized.isNotEmpty)
                _CategoryGroup(
                  title: 'Uncategorized',
                  exercises: uncategorized,
                  folderByExercise: folderByExercise,
                  pieceByExercise: pieceByExercise,
                  isDark: isDark,
                ),
              if (unlinkedFolders.isNotEmpty || unlinkedPieces.isNotEmpty)
                _LegacyGroup(
                  folders: unlinkedFolders,
                  pieces: unlinkedPieces,
                  isDark: isDark,
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Category group ────────────────────────────────────────────────────────────

class _CategoryGroup extends StatelessWidget {
  final String title;
  final List<Exercise> exercises;
  final Map<int, ScoreFolder> folderByExercise;
  final Map<int, MetronomePiece> pieceByExercise;
  final bool isDark;

  const _CategoryGroup({
    required this.title,
    required this.exercises,
    required this.folderByExercise,
    required this.pieceByExercise,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (exercises.isEmpty) return const SizedBox.shrink();
    // Material (not a decorated Container): the tiles inside need an ink
    // surface, and a DecoratedBox over them trips a debug assertion.
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(
              Icons.folder_outlined,
              color: AppColors.indigoNavySoft,
              size: 24,
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            childrenPadding: const EdgeInsets.only(bottom: 6),
            children: exercises
                .map(
                  (e) => _ExerciseTile(
                    exercise: e,
                    folder: folderByExercise[e.id],
                    piece: pieceByExercise[e.id],
                    isDark: isDark,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

// ── Exercise tile with link badge ────────────────────────────────────────────

class _ExerciseTile extends ConsumerWidget {
  final Exercise exercise;
  final ScoreFolder? folder;
  final MetronomePiece? piece;
  final bool isDark;

  const _ExerciseTile({
    required this.exercise,
    required this.folder,
    required this.piece,
    required this.isDark,
  });

  String get _badge {
    if (folder != null && piece != null) return 'score and piece linked';
    if (folder != null) return 'score linked';
    if (piece != null) return 'piece linked';
    return 'nothing linked yet';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasAny = folder != null || piece != null;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 28, right: 16),
      title: Text(
        exercise.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        _badge,
        style: theme.textTheme.labelSmall?.copyWith(
          color: hasAny
              ? AppColors.indigoNavySoft
              : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          fontWeight: hasAny ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 18,
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
      ),
      onTap: () => _openActions(context, ref),
    );
  }

  // The exercise's hub: open what exists, offer to add what doesn't.
  Future<void> _openActions(BuildContext context, WidgetRef ref) async {
    // Capture repositories NOW: the onTap closures below run after awaits
    // and Navigator.pops, by which point this tile may have been rebuilt —
    // touching `ref` then throws "Cannot use ref after the widget was
    // disposed". Plain repo objects stay valid regardless.
    final scoreRepo = ref.read(scoreRepositoryProvider);
    final pieceRepo = ref.read(pieceRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                exercise.name,
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            // ── Score ────────────────────────────────────────────────────
            if (folder != null) ...[
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Open Score'),
                subtitle: const Text('Rehearsal canvas with annotations'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScoreViewerScreen(folder: folder!),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.collections_outlined),
                title: const Text('Manage Pages'),
                subtitle: const Text('Import, rename, reorder, delete'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScoreFolderScreen(folder: folder!),
                    ),
                  );
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: const Text('Add Sheet Music'),
                subtitle: const Text(
                  'This exercise has no score yet — attach one',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final id = await scoreRepo.createFolder(
                    exercise.name,
                    exerciseId: exercise.id,
                    linkedPieceId: piece?.id,
                  );
                  final created = await scoreRepo.getFolderById(id);
                  if (created != null && context.mounted) {
                    // Straight into page import.
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScoreFolderScreen(folder: created),
                      ),
                    );
                  }
                },
              ),
            const Divider(height: 1),
            // ── Piece ────────────────────────────────────────────────────
            if (piece != null) ...[
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Play Piece'),
                subtitle: const Text('Metronome follows the section roadmap'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PiecePlayerScreen(
                        pieceId: piece!.id,
                        title: piece!.title,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Piece Sections'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PieceEditorScreen(
                        pieceId: piece!.id,
                        title: piece!.title,
                      ),
                    ),
                  );
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.timeline_outlined),
                title: const Text('Add Piece Map'),
                subtitle: const Text(
                  'No measure tracking yet — design sections for this exercise',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final pieceId = await pieceRepo.create(
                    exercise.name,
                    exerciseId: exercise.id,
                  );
                  // Bind to the exercise's score so the canvas plays it.
                  if (folder != null) {
                    await scoreRepo.setLinkedPiece(folder!.id, pieceId);
                  }
                  if (context.mounted) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PieceEditorScreen(
                          pieceId: pieceId,
                          title: exercise.name,
                        ),
                      ),
                    );
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Legacy standalone items (pre-v8) ──────────────────────────────────────────

class _LegacyGroup extends ConsumerWidget {
  final List<ScoreFolder> folders;
  final List<MetronomePiece> pieces;
  final bool isDark;

  const _LegacyGroup({
    required this.folders,
    required this.pieces,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(
              Icons.inventory_2_outlined,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              size: 24,
            ),
            title: Text(
              'Not linked to an exercise',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              'Created before scores & pieces merged',
              style: theme.textTheme.labelSmall,
            ),
            childrenPadding: const EdgeInsets.only(bottom: 6),
            children: [
              for (final f in folders)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 28, right: 16),
                  leading: const Icon(Icons.menu_book_outlined, size: 18),
                  title: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: Text('score', style: theme.textTheme.labelSmall),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScoreViewerScreen(folder: f),
                    ),
                  ),
                ),
              for (final p in pieces)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 28, right: 16),
                  leading: const Icon(Icons.timeline_outlined, size: 18),
                  title: Text(
                    p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: Text('piece', style: theme.textTheme.labelSmall),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PiecePlayerScreen(pieceId: p.id, title: p.title),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
