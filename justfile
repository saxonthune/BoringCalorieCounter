# iOS justfile — agent-friendly build/run/test commands.
# Project facts are filled in below. Per-machine values come from a gitignored
# credentials.env (copy credentials.env.example):
#   DEVICE=<Identifier from `just devices`>
#   TEAM=<optional; project already sets DEVELOPMENT_TEAM>

set dotenv-load
set dotenv-filename := "credentials.env"

# --- project facts ---
container  := "-project BoringCalorieCounter.xcodeproj"
scheme     := "BoringCalorieCounter"
bundle_id  := "zone.saxon.BoringCalorieCounter"
product    := "BoringCalorieCounter.app"
proc_name  := "BoringCalorieCounter"

# --- defaults (override: just run sim="iPhone 16 Pro") ---
sim := "iPhone 16"

sim_derived    := "build/sim"
device_derived := "build/device"
sim_app        := sim_derived / "Build/Products/Debug-iphonesimulator" / product
device_app     := device_derived / "Build/Products/Debug-iphoneos" / product
build_log      := "build/last-build.log"

default:
    @just --list

# Build for the simulator (full log → build/last-build.log)
build:
    @mkdir -p build
    @xcodebuild {{container}} -scheme {{scheme}} -configuration Debug \
        -destination "platform=iOS Simulator,name={{sim}}" \
        -derivedDataPath {{sim_derived}} build > {{build_log}} 2>&1 \
        && echo "BUILD OK ({{build_log}})" \
        || { grep -E "error:|BUILD FAILED" {{build_log}} | head -40; exit 1; }

# Build, (re)install, and launch on the simulator
run: build
    -@xcrun simctl boot "{{sim}}" 2>/dev/null
    @open -a Simulator
    -@xcrun simctl terminate "{{sim}}" {{bundle_id}} 2>/dev/null
    xcrun simctl install "{{sim}}" "{{sim_app}}"
    xcrun simctl launch "{{sim}}" {{bundle_id}}

# Like run, but stays attached and prints stdout/stderr + crash output
debug: build
    -@xcrun simctl boot "{{sim}}" 2>/dev/null
    @open -a Simulator
    -@xcrun simctl terminate "{{sim}}" {{bundle_id}} 2>/dev/null
    xcrun simctl install "{{sim}}" "{{sim_app}}"
    xcrun simctl launch --console-pty "{{sim}}" {{bundle_id}}

# Stream the simulator log for the app
logs:
    xcrun simctl spawn "{{sim}}" log stream --level debug --predicate 'process == "{{proc_name}}"'

# Print the newest crash report for the app
crash:
    @f=$(ls -t ~/Library/Logs/DiagnosticReports/{{proc_name}}-*.ips 2>/dev/null | head -1); \
        if [ -n "$f" ]; then echo "==> $f"; cat "$f"; else echo "No {{proc_name}} crash reports found."; fi

# Run tests on the simulator (scope: just test only=AppTests/FooTests)
test only="":
    @mkdir -p build
    @xcodebuild test {{container}} -scheme {{scheme}} \
        -destination "platform=iOS Simulator,name={{sim}}" \
        -derivedDataPath {{sim_derived}} \
        {{ if only != "" { "-only-testing:" + only } else { "" } }} \
        > build/last-test.log 2>&1 \
        && echo "TESTS OK (build/last-test.log)" \
        || { grep -E "error:|failed|TEST FAILED" build/last-test.log | head -60; exit 1; }

# List available simulators
sims:
    xcrun simctl list devices available

# List paired physical devices
devices:
    xcrun devicectl list devices

# Build for the physical device (TEAM optional; defaults to the project setting)
device-build:
    @mkdir -p build
    @xcodebuild {{container}} -scheme {{scheme}} -configuration Debug \
        -destination 'generic/platform=iOS' \
        -derivedDataPath {{device_derived}} \
        -allowProvisioningUpdates ${TEAM:+DEVELOPMENT_TEAM="$TEAM"} build > {{build_log}} 2>&1 \
        && echo "DEVICE BUILD OK ({{build_log}})" \
        || { grep -E "error:|BUILD FAILED" {{build_log}} | head -40; exit 1; }

# Build, install, and launch on the physical device (needs DEVICE)
device-run: device-build
    @test -n "${DEVICE:-}" || { echo "DEVICE is unset — cp credentials.env.example credentials.env, then set DEVICE from `just devices`"; exit 1; }
    xcrun devicectl device install app --device "$DEVICE" "{{device_app}}"
    xcrun devicectl device process launch --device "$DEVICE" --terminate-existing {{bundle_id}}

# device-run attached to the console; Ctrl-C terminates the app
device-debug: device-build
    @test -n "${DEVICE:-}" || { echo "DEVICE is unset — cp credentials.env.example credentials.env, then set DEVICE from `just devices`"; exit 1; }
    xcrun devicectl device install app --device "$DEVICE" "{{device_app}}"
    xcrun devicectl device process launch --device "$DEVICE" --console --terminate-existing {{bundle_id}}

# Remove build outputs
clean:
    rm -rf build

# Reinstall + launch the last device build without rebuilding
device-install:
    @test -n "${DEVICE:-}" || { echo "DEVICE is unset — cp credentials.env.example credentials.env, then set DEVICE from \`just devices\`"; exit 1; }
    xcrun devicectl device install app --device "$DEVICE" "{{device_app}}"
    xcrun devicectl device process launch --device "$DEVICE" --terminate-existing {{bundle_id}}
