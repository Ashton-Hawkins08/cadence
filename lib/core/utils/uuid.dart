import 'dart:math';

final _rng = Random.secure();

/// RFC-4122 version-4 UUID, dependency-free.
///
/// Used as the global identity (`syncId`) for every syncable database row:
/// local auto-increment ids differ between devices, so cross-device sync
/// needs an identifier minted once at row creation and carried everywhere.
String uuidV4() {
  final b = List<int>.generate(16, (_) => _rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
  final h =
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
