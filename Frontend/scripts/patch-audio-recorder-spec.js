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
