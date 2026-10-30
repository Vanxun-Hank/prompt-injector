#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c debug
bin_dir="$(swift build -c debug --show-bin-path)"
build_id="$(date -u +%Y%m%dT%H%M%SZ)"
revision="$(git rev-parse --short=12 HEAD 2>/dev/null || printf 'unversioned')"
source_fingerprint="$(
  {
    shasum -a 256 Package.swift scripts/build-app.sh
    if command -v rg >/dev/null 2>&1; then
      rg --files macOS/PromptInjector macOS/CSQLite -g '*.swift' -g '*.json' -g '*.h' -g '*.modulemap'
    else
      find macOS/PromptInjector macOS/CSQLite -type f \( -name '*.swift' -o -name '*.json' -o -name '*.h' -o -name '*.modulemap' \)
    fi | LC_ALL=C sort | while IFS= read -r source_file; do shasum -a 256 "$source_file"; done
  } | shasum -a 256 | awk '{print $1}'
)"
# Keep the signed bundle outside File Provider managed Documents folders, which
# can attach FinderInfo to .app directories after signing and invalidate them.
app_dir="${PROMPT_INJECTOR_APP_OUTPUT:-$HOME/Library/Application Support/Prompt Injector/Build/Prompt Injector.app}"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/PromptInjector" "$app_dir/Contents/MacOS/PromptInjector"
rm -rf "$app_dir/Contents/Resources/PromptInjector_PromptInjector.bundle" "$app_dir/Contents/MacOS/PromptInjector_PromptInjector.bundle"
cp "$bin_dir/PromptInjector_PromptInjector.bundle/prompts.json" "$app_dir/Contents/Resources/"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.promptinjector.local</string>
<key>CFBundleName</key><string>Prompt Injector</string>
<key>CFBundleDisplayName</key><string>Prompt Injector</string>
<key>CFBundleExecutable</key><string>PromptInjector</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Add :PIBuildID string $build_id" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :PISourceFingerprint string $source_fingerprint" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :PIRevision string $revision" "$app_dir/Contents/Info.plist"
xattr -dr com.apple.FinderInfo "$app_dir" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$app_dir" 2>/dev/null || true
signing_identity="${PROMPT_INJECTOR_SIGN_IDENTITY:-}"
if [ -z "$signing_identity" ]; then
  identities=($(security find-identity -v -p codesigning | awk 'length($2) == 40 && $2 ~ /^[0-9A-F]+$/ { print $2 }'))
  if [ "${#identities[@]}" -eq 1 ]; then
    signing_identity="${identities[0]}"
  else
    printf 'Set PROMPT_INJECTOR_SIGN_IDENTITY to a valid signing identity; ad-hoc signing requires renewed Accessibility permission after builds.\n' >&2
    signing_identity="-"
  fi
fi
codesign --force --sign "$signing_identity" "$app_dir"
codesign --verify --strict "$app_dir"
project_app="$PWD/build/Prompt Injector.app"
mkdir -p "$PWD/build"
cat > "$PWD/build/build-info.json" <<META
{"version":"0.2.0","buildID":"$build_id","sourceFingerprint":"$source_fingerprint","revision":"$revision"}
META
if [ "$app_dir" != "$project_app" ]; then
  if [ -d "$project_app" ] && [ ! -L "$project_app" ]; then
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$project_app/Contents/Info.plist")
    if [ "$bundle_id" != "com.promptinjector.local" ]; then
      printf 'Refusing to replace an unrelated app: %s\n' "$project_app" >&2
      exit 1
    fi
    rm -rf "$project_app"
  fi
  ln -sfn "$app_dir" "$project_app"
fi
printf '%s\n' "$app_dir"
