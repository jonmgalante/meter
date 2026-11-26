# Repeat Workout rehearsal

From the feature checkout on a Mac with Xcode 26.1.1 and the iOS 26.1 runtime, pass the PR's base commit to the rehearsal.

```sh
base=$(git merge-base HEAD origin/main)
bash Tests/Repeat/rehearse.sh "$base"
```

The script creates a fresh iPhone 17 simulator, builds the base app and seeds its normal on-disk store with the base revision's model. It records every historical field, UUID, physical row, ownership link and persistent-history entry through an independent SQLite reader. The reference includes an unattached piece, fractional dates and splits, a non-midnight stored day key, multiline notes, and groups with unknown, zero and recorded rest.

The feature installs in place. XCTest exercises Cancel, swipe-down, backgrounding, both detail and manual Add routes, save failure, retry after uncertain commit and repeated taps. The timed comparison starts in the full Workouts tab and ends on returning there after saving the same 4 × 1,000 m workout with 2:30 rest.

The five source sessions cover 1 × 6,000 m, 4 × 1,000 m with extra session meters, 10 × 250 m, mixed groups stored out of sequence and a total-only workout. The independent audit expects seven new workouts and eight new pieces across the five repeats and two manual saves. Deletion runs on a separate clone and removes the repeated mixed workout and its three pieces. A failed check stops the script and retains the simulator, store, companions and results. Generated data lives outside the checkout.

For a signed spare-device check, install the candidate over a disposable prior-build log. Record the old values independently, repeat the timing and dismissal checks, and compare both tabs after relaunch. Installation on the primary iPhone requires a verified independent recovery copy and a passing in-place upgrade rehearsal.
