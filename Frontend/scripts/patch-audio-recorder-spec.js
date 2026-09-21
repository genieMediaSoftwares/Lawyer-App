/**
 * react-native-audio-recorder-player@5.0.0-rc.1 ships a TurboModule spec whose
 * `AudioSet.AVFormatIDKeyIOS` is typed `number | string`. React Native's codegen
 * refuses heterogeneous unions, so `generateCodegenArtifactsFromSchema` dies with:
 *
 *   HeterogeneousUnionError: Non-homogenous union member types
 *     at parseValidUnionType (@react-native/codegen/lib/generators/Utils.js:65)
 *
 * The field is iOS-only and we pass the string 'aac' (see src/services/voiceRecorder.ts),
 * so narrowing it to `string` costs us nothing and unblocks the Android build.
 *
 * Runs from `postinstall` because the fix lives in node_modules and would otherwise
 * be lost on every `npm install`. patch-package is the usual tool for this, but it
 * cannot diff this package on Windows without long-path support enabled — git fails
 * with "Filename too long" on the AGP dex transform directories.
 *
 * Idempotent: a no-op once the union is already narrowed, and silent if the package
 * is absent.
 */
const fs = require('fs');
const path = require('path');

const PKG = 'react-native-audio-recorder-player';
const TARGETS = ['src/NativeAudioRecorderPlayer.ts', 'src/NativeAudioRecorderPlayer.web.ts'];
const FROM = 'AVFormatIDKeyIOS?: number | string;';
const TO = 'AVFormatIDKeyIOS?: string;';

let patched = 0;
let alreadyOk = 0;

for (const rel of TARGETS) {
  const file = path.join(__dirname, '..', 'node_modules', PKG, rel);
  if (!fs.existsSync(file)) continue;

  const before = fs.readFileSync(file, 'utf8');
  if (before.includes(TO) && !before.includes(FROM)) {
    alreadyOk++;
    continue;
  }
  if (!before.includes(FROM)) {
    console.warn(
      `[patch-audio-recorder-spec] ${rel}: expected union not found. The package may ` +
        `have changed upstream — re-check whether this patch is still needed.`,
    );
    continue;
  }
  fs.writeFileSync(file, before.split(FROM).join(TO));
  patched++;
}

if (patched > 0) {
  console.log(`[patch-audio-recorder-spec] narrowed AVFormatIDKeyIOS in ${patched} file(s).`);
} else if (alreadyOk > 0) {
  console.log('[patch-audio-recorder-spec] already applied.');
}
