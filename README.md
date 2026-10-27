# Countdown / Countup

Native SwiftUI iPhone app source, targeting iOS 17+. The final product name is undecided; the installed development label is **Countdown**.

The app implements date-based countdowns and countups, the shared single-smile face, bundled Nunito typography, calendar tickets, circular date selectors, and gentle motion. It has no web runtime or third-party app dependencies.

**This source has not been compiled or run in Xcode on this Windows machine.** Swift grammar, Xcode structure, resource, font, and icon checks pass. Twenty-one XCTest cases are included but have not been executed here. See [validation and remaining release work](docs/BUILD_STATUS.md).

## Run on a Mac

1. Open `CountdownApp.xcodeproj` in Xcode 15 or newer.
2. Choose the **CountdownApp** scheme and an iPhone simulator running iOS 17+.
3. Run. The normal app starts with an empty collection; “Try a few examples” creates editable local examples.
4. To install on a phone, sign into the Apple Developer account for team `MD42BG8ZP4` (the same team as StepFurr) and replace the placeholder `com.example.countdownapp` bundle identifier in the app target's Signing & Capabilities settings. Automatic signing and the team are configured for both app and test targets.

Node, npm, FontTools, and XcodeGen are **not required to run the included project**. Fonts, vector components, the app icon, and shared scheme are included.

For a deterministic design preview, add `--demo` under Scheme → Run → Arguments. It uses 27 October 2026 and in-memory examples. Demo mode does not read or write your saved event collection and does not schedule notifications.

## Included

- Countdowns and Countups tabs, horizontal event browsing, next-event shortcut, searchable/tag-filtered lists.
- Add/edit forms with month/day wheels, year selection, and a standard calendar alternative.
- Reusable vector face and sun, gift, flower, sprout, and house illustrations; five event themes.
- Event detail, notes, tags, custom countup labels, and native share-image export.
- Weekly/monthly/yearly countdown recurrence, including explicit leap-day behavior.
- Atomic versioned local storage, recoverable deletion, and raw collection export.
- Optional local countdown reminders at 9 AM; permission handling and event notification routing.
- Wheel snapping, numeric transitions, brief eye motion, save feedback, haptics, and reduced-motion handling.
- Dynamic Type layouts and adjustable VoiceOver date controls.

The add button and selected ticket expand into their destination surfaces, with full-size text revealed through a moving mask. These custom transitions still need device tuning. The app deliberately has no stopwatch, focus timer, or “Moments” section.

## Date behavior

Events represent all-day Gregorian dates in the current local time zone. Counts use calendar-day arithmetic, not elapsed seconds. The app refreshes on foregrounding, significant time changes, and while active. Expired countdowns remain at zero until you explicitly convert them to countups. Recurrence advances after the occurrence day and retains the original day-of-month anchor.

Data lives at `Application Support/CountdownApp/events-v1.json`. A failed load leaves the file intact and blocks writes until a successful retry. Removal moves events into Recently deleted; restore them in Settings. Preferences and selected event IDs use the app's own UserDefaults.

Reminders require both the app-wide preference and a per-event toggle. The scheduler queues the nearest 60 occurrences, up to 12 future occurrences per recurring event, and refreshes on edits, local-day changes, and app launch. iOS controls delivery; the app does not run a background timer.

## Verification

On a Mac, run the domain tests without opening the app:

```sh
swift test
```

Run the same tests against the app target using Product → Test in Xcode. A macOS GitHub Actions workflow is included to run `swift test` and compile the native app/test bundle; it has not been run for this repository yet.

Optional source-tool checks on Windows or Mac:

```sh
npm ci
npm run check
```

After adding/removing Swift files, regenerate the checked-in Xcode project with `npm run project`, or use XcodeGen on a Mac from the repository root:

```sh
xcodegen generate --spec project.yml
open CountdownApp.xcodeproj
```

The root [project.yml](project.yml) declares the app, hosted unit tests, font folder, assets, privacy manifest, and shared scheme. Both generators preserve team `MD42BG8ZP4`. Keep signing settings and bundle identifiers synchronized between `project.yml` and `scripts/generate-project.mjs`; `npm run check` checks their settings against the generated project. The source archive includes the spec. See the [XcodeGen spec documentation](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md) for its format.

`npm run icon` regenerates the opaque app icon from `docs/design/app-icon.svg`. `npm run package` creates a source archive for transferring to a Mac.

`npm run artwork` exports the 12 SVG designs defined in `scripts/generate-artwork.mjs` to [docs/design/svg](docs/design/svg/) and produces their native 1x/2x/3x asset-catalog images. They include the filled/outline calendar arrows, settings/repeat/palette icons, and seaside, garden, gift, sprout, and home ticket scenery. Update the generator when changing these designs so exports remain reproducible. The face, numbers, and text stay live SwiftUI components.

The home tickets use the supplied reference's proportions, large Nunito counts, cream background, and illustrated edges. The date editor keeps the paired month/day eyes and single smile; tap the year to open the standard calendar. The toolbar's more-options button reveals tags, notes, reminders, and the custom countup label. The revised screens still require simulator/device visual verification.

## Fonts and design

Your supplied regular, bold, and heavy font files originally shared the PostScript name `Nunito-ExtraLight`, despite having distinct weights. Bundled copies use `CalendarNunito-Regular`, `CalendarNunito-Bold`, and `CalendarNunito-Heavy` so iOS can register all three. The glyph outlines and weights are preserved, and the original files outside this repo are untouched. The SIL Open Font License is bundled and available in Settings.

The name-fixing script is `scripts/prepare-fonts.py`; rerunning it requires Python with FontTools and the original font folder as its argument. Normal app development uses the already prepared files.

See [implementation plan](IMPLEMENTATION_PLAN.md), [motion notes](docs/MOTION.md), and [design references](docs/design/).

RevenueCat, pricing, widgets, cloud sync, final naming, and competition submission details are not configured. They need explicit product/release decisions before integration.
