#!/bin/bash
# Pass the accepted app revision to rehearse. The script creates and retains two disposable simulators.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
prior=${1:?Pass the accepted base commit SHA}
out=$(mktemp -d /private/tmp/meter-repeat-rehearsal.XXXXXXXX)
mkdir "$out/prior"
git archive "$prior" | tar -x -C "$out/prior"
device=$(xcrun simctl create Meter-Disposable-Repeat-Rehearsal \
    com.apple.CoreSimulator.SimDeviceType.iPhone-17 com.apple.CoreSimulator.SimRuntime.iOS-26-1)
echo "Results $out. Disposable simulator $device."
xcrun simctl boot "$device"
xcrun simctl bootstatus "$device" -b
bundle=com.jongalante.meter
xcodebuild -project "$out/prior/Meter.xcodeproj" -scheme MeteriOS -configuration Debug \
    -destination "id=$device" -derivedDataPath "$out/prior-build" build CODE_SIGNING_ALLOWED=NO > "$out/prior-build.log"
xcrun simctl install "$device" "$out/prior-build/Build/Products/Debug-iphonesimulator/MeteriOS.app"

store_path() {
    local container
    container=$(xcrun simctl get_app_container "$device" "$bundle" data) || return 1
    case "$container" in
        */CoreSimulator/Devices/"$device"/data/Containers/Data/Application/*)
            echo "$container/Library/Application Support/default.store" ;;
        *) return 1 ;;
    esac
}
audit() { python3 Tests/Repeat/audit.py "$1" "$(store_path)" "$out/$2.json"; }
reopen() { xcrun simctl launch --terminate-running-process "$device" "$bundle"; }
unit=MeteriOSTests/RepeatWorkoutTests
ui=MeteriOSRepeatUITests/RepeatRehearsal
run_test() {
    local name=$1 scheme=$2 method=$3
    xcodebuild -project Meter.xcodeproj -scheme "$scheme" -configuration Debug -destination "id=$device" \
        -parallel-testing-enabled NO -derivedDataPath "$out/build" -resultBundlePath "$out/$name.xcresult" \
        "-only-testing:$method" test CODE_SIGNING_ALLOWED=NO > "$out/$name.log"
}

store=$(store_path)
mkdir -p "$(dirname "$store")"
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun --sdk iphonesimulator swiftc -sdk "$sdk" -target "$(uname -m)-apple-ios26.1-simulator" \
    -module-name MeteriOS -module-cache-path "$out/modules" "$out/prior/MeteriOS/Models/ErgWorkout.swift" \
    Tests/Repeat/MakePriorStore.swift -o "$out/make-prior"
xcrun simctl spawn "$device" "$out/make-prior" "$store"
audit record prior
reopen
sleep 3
xcrun simctl terminate "$device" "$bundle"
audit unchanged prior
run_test Unit MeteriOS "$unit"
audit unchanged prior
scheme=MeteriOSRepeatRehearsal
run_test Cancel "$scheme" "$ui/testCancelSwipeAndBackground"
reopen
audit unchanged prior
audit record after-cancel
TEST_RUNNER_METER_REPEAT_PHASE=timing run_test Timing "$scheme" "$ui/testRepeatVersusManualFromFullTab"
audit timed prior
TEST_RUNNER_METER_REPEAT_PHASE=examples run_test Examples "$scheme" "$ui/testOtherRepeatsAndManualSummaryAdd"
audit saved prior
audit record saved
TEST_RUNNER_METER_REPEAT_PHASE=verify run_test Relaunch "$scheme" "$ui/testWorkoutsAndSummaryAfterRelaunch"
audit unchanged saved
xcrun simctl shutdown "$device"
device=$(xcrun simctl clone "$device" Meter-Disposable-Repeat-Delete-Copy)
echo "Deletion copy $device"
xcrun simctl boot "$device"
xcrun simctl bootstatus "$device" -b
audit unchanged saved
TEST_RUNNER_METER_REPEAT_PHASE=delete run_test Delete "$scheme" "$ui/testDeleteOnlyNewMixedWorkoutOnCopy"
reopen
audit deleted saved
audit record after-delete
xcrun simctl shutdown "$device"
grep 'from Workouts through save and return' "$out/Timing.log"
