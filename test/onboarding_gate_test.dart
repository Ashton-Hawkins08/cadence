import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cadence/app.dart';

// onboardingCompleteProvider gates the entire welcome flow (Welcome, Create
// Account, How It Works, Name, Instrument). A returning user whose device
// already has a saved name + instrument must never see any of it again,
// even if the completion flag itself is somehow stale/false — that flag
// mismatch is exactly what this provider self-heals.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('flag already true short-circuits without touching settings',
      () async {
    SharedPreferences.setMockInitialValues(
        {'flutter.onboarding_complete': true});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(onboardingCompleteProvider.future), isTrue);
  });

  test('flag false + no profile yet -> onboarding still runs', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(onboardingCompleteProvider.future), isFalse);
  });

  test('flag false but a profile already exists -> self-heals to complete',
      () async {
    SharedPreferences.setMockInitialValues({
      'flutter.first_name': 'Ashton',
      'flutter.instrument': 'Trumpet',
      // onboarding_complete deliberately absent — the exact mismatch this
      // guards against.
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(onboardingCompleteProvider.future), isTrue,
        reason: 'an existing name+instrument means setup already happened');

    // setMockInitialValues seeds the raw (flutter.-prefixed) storage layer,
    // but the SharedPreferences instance API strips that prefix itself —
    // so reads through it use the plain key, same as the app code does.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_complete'), isTrue,
        reason: 'the flag itself must be repaired so future reads are cheap');
  });

  test('only a first name with no instrument yet is NOT treated as complete',
      () async {
    SharedPreferences.setMockInitialValues({'flutter.first_name': 'Ashton'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(onboardingCompleteProvider.future), isFalse,
        reason: 'a half-finished profile must still complete onboarding');
  });
}
