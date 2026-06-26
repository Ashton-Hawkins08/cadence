import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drives the active bottom-nav tab in AppShell.
/// 0=Home  1=Log  2=Manage(sheet)  3=Calendar  4=Stats
final navIndexProvider = StateProvider<int>((ref) => 0);
