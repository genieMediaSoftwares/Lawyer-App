/**
 * Builds the Android release APK.
 *
 *   npm run android:release          production: every ABI in gradle.properties
 *   npm run android:release:device   testing: arm64-v8a only, ~4x less C++ work
 *   add --clean to wipe build outputs and CMake caches first
 *
 * Why a script rather than a bare `gradlew`:
 *
 * - ccache for *every* native module. React Native's ReactNative-application.cmake
 *   picks ccache up for `:app` on its own, but worklets, reanimated and screens
 *   ship their own CMakeLists with no launcher. CMake >= 3.17 initialises
 *   CMAKE_<LANG>_COMPILER_LAUNCHER from the environment, so setting it here
 *   covers them without editing node_modules. Wrapping twice (`:app` gets both)
 *   is harmless — verified against NDK 27 clang.
 *
 * - Gradle user home on the project's volume. AGP hard-links prefab `.so`
 *   files out of the Gradle cache into each module's build dir; across volumes
 *   (cache on C:, project on D:) NTFS refuses, and every link falls back to a
 *   copy with "Hard link from … failed. Doing a slower copy instead." If
 *   GRADLE_USER_HOME is not already set, the default is used unchanged.
 *
 * Nothing here hides output: Gradle's stdout/stderr are passed straight through.
 */
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const device = args.includes('--device');
const clean = args.includes('--clean');

const root = path.join(__dirname, '..');
const androidDir = path.join(root, 'android');

const findOnPath = name => {
  const exts = process.platform === 'win32' ? ['.exe', '.cmd', ''] : [''];
  for (const dir of (process.env.PATH || '').split(path.delimiter)) {
    for (const ext of exts) {
      const candidate = path.join(dir, name + ext);
      if (dir && fs.existsSync(candidate)) return candidate;
    }
  }
  return null;
};

const env = { ...process.env };

const ccache = findOnPath('ccache');
if (ccache) {
  const launcher = ccache.split(path.sep).join('/');
  env.CMAKE_C_COMPILER_LAUNCHER = launcher;
  env.CMAKE_CXX_COMPILER_LAUNCHER = launcher;
  console.log(`[android-build] ccache: ${launcher}`);
} else {
  console.log('[android-build] ccache not found on PATH — native code compiles uncached.');
}
console.log(
  `[android-build] GRADLE_USER_HOME: ${env.GRADLE_USER_HOME || '(Gradle default)'}`,
);

const removeDir = dir => fs.rmSync(dir, { recursive: true, force: true });

if (clean) {
  // `gradlew clean` leaves every module's .cxx (CMake cache) behind, and those
  // pin the ABI list and compiler launcher from the previous configure.
  const targets = [
    path.join(androidDir, 'app', 'build'),
    path.join(androidDir, 'app', '.cxx'),
    path.join(androidDir, 'build'),
  ];
  const nm = path.join(root, 'node_modules');
  const scan = dir => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const pkg = path.join(dir, entry.name);
      if (entry.name.startsWith('@')) {
        scan(pkg);
        continue;
      }
      targets.push(path.join(pkg, 'android', 'build'), path.join(pkg, 'android', '.cxx'));
    }
  };
  scan(nm);
  let removed = 0;
  for (const t of targets) {
    if (fs.existsSync(t)) {
      removeDir(t);
      removed++;
    }
  }
  console.log(`[android-build] clean: removed ${removed} build/.cxx directories`);
}

const gradleArgs = ['assembleRelease'];
if (device) gradleArgs.push('-PreactNativeArchitectures=arm64-v8a');

// Absolute path: cmd.exe does not search the working directory when
// NoDefaultCurrentDirectoryInExePath is set, so a bare `gradlew.bat` can fail
// with "not recognized" depending on the machine.
const gradlew = path.join(androidDir, process.platform === 'win32' ? 'gradlew.bat' : 'gradlew');
console.log(`[android-build] ${gradlew} ${gradleArgs.join(' ')}`);

const started = Date.now();
const result = spawnSync(`"${gradlew}"`, gradleArgs, {
  cwd: androidDir,
  env,
  stdio: 'inherit',
  shell: process.platform === 'win32',
});
const seconds = Math.round((Date.now() - started) / 1000);
if (result.error) {
  console.error(`[android-build] could not start Gradle: ${result.error.message}`);
}

console.log(
  `[android-build] ${result.status === 0 ? 'SUCCEEDED' : 'FAILED'} in ` +
    `${Math.floor(seconds / 60)}m ${seconds % 60}s (${device ? 'device: arm64-v8a' : 'production: all ABIs'})`,
);
if (result.status === 0) {
  console.log(
    `[android-build] APK: ${path.join(androidDir, 'app', 'build', 'outputs', 'apk', 'release', 'app-release.apk')}`,
  );
}
process.exit(result.status ?? 1);
