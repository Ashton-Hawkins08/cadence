"""Pre-upload sanity checks for a Cadence release bundle (AAB).

Run after `flutter build appbundle`:
    python tool/preflight_aab.py

Checks the things that have bitten us before: wrong signing key, reused
version code, Firebase / ad-ID leftovers, stale launcher icon, wrong package.
Exit code 0 = all clear, 1 = at least one FAIL.
"""
import os, re, subprocess, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AAB = os.path.join(ROOT, "build", "app", "outputs", "bundle", "release", "app-release.aab")
MERGED = os.path.join(ROOT, "build", "app", "intermediates", "merged_manifest", "release",
                      "processReleaseMainManifest", "AndroidManifest.xml")
KEYTOOL = r"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
EXPECTED_PACKAGE = "com.cadencecmh.app"
EXPECTED_SIGNER = "CN=Ashton Hawkins"
MIN_TARGET_SDK = 35        # Play's current floor is 35; we ship 36
LAST_UPLOADED_CODE = 2     # bump this after each upload to Play

results = []
def check(ok, label, detail=""):
    results.append(ok)
    print(("PASS  " if ok else "FAIL  ") + label + (f"  ({detail})" if detail else ""))

def read(p):
    with open(p, encoding="utf-8", errors="ignore") as f:
        return f.read()

# --- the bundle itself
check(os.path.exists(AAB), "AAB exists", AAB)
if not os.path.exists(AAB):
    sys.exit(1)
size_mb = os.path.getsize(AAB) / 1e6
check(10 < size_mb < 150, "AAB size is sane", f"{size_mb:.1f} MB")

# --- signing key
out = subprocess.run([KEYTOOL, "-printcert", "-jarfile", AAB], capture_output=True, text=True).stdout
check(EXPECTED_SIGNER in out, "Signed with the upload key (not debug)", out.splitlines()[0] if out else "no cert found")
check("Android Debug" not in out, "Not signed with the Android debug key")

# --- manifest (merged text manifest from the same build)
m = read(MERGED) if os.path.exists(MERGED) else ""
check(bool(m), "Merged manifest found")
pkg = re.search(r'package="([^"]+)"', m)
check(bool(pkg) and pkg.group(1) == EXPECTED_PACKAGE, "Package name", pkg.group(1) if pkg else "missing")
vc = re.search(r'android:versionCode="(\d+)"', m)
check(bool(vc) and int(vc.group(1)) > LAST_UPLOADED_CODE, "Version code is higher than last upload",
      f"{vc.group(1) if vc else '?'} vs {LAST_UPLOADED_CODE}")
tsdk = re.search(r'android:targetSdkVersion="(\d+)"', m)
check(bool(tsdk) and int(tsdk.group(1)) >= MIN_TARGET_SDK, "targetSdk meets Play minimum", tsdk.group(1) if tsdk else "missing")
check("com.google.android.gms.permission.AD_ID" not in m, "No advertising-ID permission")
check("android.permission.INTERNET" not in m, "No INTERNET permission (app is fully offline)")
perms = sorted(set(re.findall(r'uses-permission[^>]*android:name="([^"]+)"', m)))
allowed = {"android.permission.WAKE_LOCK", "android.permission.FOREGROUND_SERVICE",
           "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK", "android.permission.POST_NOTIFICATIONS",
           "android.permission.RECORD_AUDIO"}
extra = [p for p in perms if p not in allowed and "DYNAMIC_RECEIVER_NOT_EXPORTED" not in p]
check(not extra, "Only the expected permissions", ", ".join(extra) if extra else f"{len(perms)} permissions")

# --- bundle contents
with zipfile.ZipFile(AAB) as z:
    names = z.namelist()
joined = "\n".join(names)
check("firebase" not in joined.lower() and "google-services" not in joined.lower(), "No Firebase files in the bundle")
check(any("arm64-v8a/libflutter.so" in n for n in names), "arm64 Flutter engine present")
check(any("res/mipmap-anydpi-v26/ic_launcher.xml" in n for n in names), "Adaptive launcher icon present")
check(any("ic_launcher_foreground" in n for n in names), "Launcher icon foreground present")
check(any("libapp.so" in n for n in names), "Compiled Dart code present (release build)")
check("kernel_blob.bin" not in joined, "No debug kernel snapshot (not a debug build)")

# --- source-tree leftovers
def grep_src(pattern):
    hits = []
    for dp, _, fs in os.walk(os.path.join(ROOT, "lib")):
        for f in fs:
            if f.endswith(".dart") and re.search(pattern, read(os.path.join(dp, f))):
                hits.append(f)
    return hits
check(not grep_src(r"package:(firebase_|cloud_firestore)"), "No Firebase imports in lib/")
dev = grep_src(r"enabled:\s*true")
check(not os.path.exists(os.path.join(ROOT, "android", "app", "google-services.json")), "No google-services.json")
check(os.path.exists(os.path.join(ROOT, "android", "key.properties")), "key.properties present (release signing)")
pub = read(os.path.join(ROOT, "pubspec.yaml"))
check("firebase" not in pub.lower(), "pubspec has no Firebase packages")
check(os.path.exists(os.path.join(ROOT, "PRIVACY.md")), "PRIVACY.md present (policy URL target)")

print()
bad = results.count(False)
print("ALL CLEAR" if not bad else f"{bad} CHECK(S) FAILED")
sys.exit(1 if bad else 0)
