# Build and verification status

27 October 2026 — source implementation on Windows.

## Implemented in source

- Native SwiftUI app and deterministic Xcode project generator, with a checked-in project and shared scheme.
- Both event types, CRUD flows, selection, browsing/search/tag filters, detailed views, share images, and trash/restore.
- Core calendar logic, recurrence/leap policies, versioned storage, and load/write failure handling.
- Canonical vector face, themed calendar tickets, five illustrated motifs, bundled fonts/license, and editable app icon.
- Calendar-eye picker plus native date picker, motion/haptics preferences, and accessibility affordances.
- Opt-in local reminders and notification routing, with serialized scheduling reconciliation.
- Source-only deterministic demo mode that leaves the saved collection untouched.

## Checks completed here

- Swift syntax parsed for every app and test source using the Swift Tree-sitter grammar.
- Xcode project parsed; all source and resource paths resolved.
- Info.plist and privacy manifest parsed.
- Three distinct bundled PostScript font names verified against UIAppFonts.
- App icon dimensions and opaque RGB PNG format verified; icon visually inspected.
- Native source archive packaged and its paths checked.

These checks do **not** type-check Swift, link Apple frameworks, run the app, or verify screen rendering.

## Native checks still required

This Windows host has no usable Swift/Xcode toolchain. WSL startup also failed. No native compilation, simulator capture, XCTest execution, code signing, device install, VoiceOver session, notification delivery test, or Instruments run has been completed.

On a Mac:

```sh
swift test
xcodebuild build-for-testing -project CountdownApp.xcodeproj -scheme CountdownApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Then run Product → Test and the app on an available iPhone simulator. The 19 tests cover reference counts, same-day/past events, recurrence boundaries, leap-day policies, DST, time zones, invalid dates, storage round trips, corrupted files, unsupported versions, duplicate IDs, and write failures.

Visually inspect a small iPhone and a large iPhone with standard and accessibility text sizes. Check the long title and multi-digit count layouts, form keyboard, screen-reader adjustable actions, and reduced motion. Test reminders after edits/deletion, changes to notification permission, and time-zone changes on a physical phone.

## Not release-ready yet

- Native validation and device motion tuning remain outstanding.
- Custom add-button/editor and ticket/detail surface transitions are implemented but have not been visually verified or profiled on a device.
- The display name and bundle identifier are temporary. Signing team `MD42BG8ZP4` is configured for app and tests; certificates/provisioning have not been verified, and no App Store record is configured.
- No RevenueCat SDK, paywall, pricing, products, purchase flow, or restore flow is present because those product decisions remain open.
- Widgets, cloud sync, exact-time events, and dedicated iPad layouts are outside this first implementation.
- The 2027 competition's schedule, location, eligibility, and submission requirements remain unverified.
- No TestFlight/App Store submission, release screenshots, or measured performance claims have been made.

## Implementation references

- [Apple ImageRenderer documentation](https://developer.apple.com/documentation/swiftui/imagerenderer) for native share-card rendering.
- [Apple accessible controls documentation](https://developer.apple.com/documentation/swiftui/accessible-controls) for the date selector's adjustable actions.
