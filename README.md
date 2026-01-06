# Meters | Rowing Log

Meters is a lightweight iOS app for manually tracking rowing/erg workouts — pieces, splits, intervals, and total meters — with Apple Health–style summaries.

## Features
- Log workouts with one or more **pieces**:
  - meters per piece
  - reps (for intervals)
  - rest (optional)
  - average split (optional)
- Track **total meters** per session (with “pieces total” + “extra” meters)
- Summary views: **Day / Week / Month / Year** with drill-down
- Highlights:
  - Month to Date
  - Year to Date
  - Last 4 Weeks
  - Average Session (recent)
  - Best 2k Ever

## Tech Stack
- SwiftUI
- SwiftData (local on-device storage)
- Swift Charts
- No accounts, no backend

## Project Structure
- `Models/` — SwiftData models (`ErgWorkout`, `ErgPiece`)
- `Views/` — SwiftUI screens (Summary, Workouts list, Add Workout, etc.)
- `Services/` — aggregation logic for D/W/M/Y summaries
- `Highlights/` — highlight calculation logic
- `UI/` — shared styling + haptics helpers

## Development
### Requirements
- Xcode (iOS target)
- iOS 17+ (SwiftData + Charts)

### Run
1. Open the Xcode project.
2. Select an iPhone simulator (or device).
3. Build & Run.

## Privacy
Meters stores workout data locally on the device using SwiftData.  
No accounts. No tracking. No third-party analytics.

## Support
Email: jonmgalante@gmail.com

## License
All rights reserved (for now).
