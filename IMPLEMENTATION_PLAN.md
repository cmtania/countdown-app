# Countdown / Countup app — implementation plan

Date: 27 October 2026  
Repository: `Z:\Git\countdown-app`  
Status: native app source implemented. See [build status](docs/BUILD_STATUS.md) for completed checks and outstanding Mac/device validation.

## 1. Product direction

Build a native iPhone app for counting days **until a future event** and **since a past event**. The experience should feel like a friendly calendar character, with clear date information and expressive, purposeful motion.

The implementation uses **SwiftUI, iPhone first, iOS 17 or later**, following the user's request to build this plan. The app name remains undecided; neither “Good Luck” nor the earlier temporary “Morrow” name is the product name.

The user intends to submit the app for a design award at a RevenueCat Shipaton event in New York in 2027. Treat that as a design objective, not a verified event schedule, eligibility statement, or award guarantee. Verify the official competition requirements before locking the submission and monetization scope.

### Established requirements

- Two primary destinations: **Countdowns** and **Countups**.
- Calendar dates and elapsed calendar days; no stopwatch, focus timer, laps, or “Moments” section.
- Use the supplied Nunito font files for regular, bold, and heavy typography.
- Use one consistent face throughout the app: two white googly eyes with dark pupils, two orange cheeks, and **one** curved orange smile. The darker inset line belongs to that single smile.
- Preserve warm cream, burnt orange, dark brown, and restrained apricot, lavender, and sage accents.
- Adapt the video's oversized circular controls and expanding panels into an original calendar interface.
- Add animation during implementation; the current images are static visual references.

### Design baseline and reference priority

1. [Latest home and date-picker concept](docs/design/home-and-date-picker.png): primary layout direction.
2. [Earlier creation forms](docs/design/creation-form-reference.png): reference for field content and appearance controls, not a competing layout.
3. [Font specimen](docs/design/nunito-specimen.png): rendered from the user-supplied fonts.
4. Video: `Z:\UserFiles\Downloads 2021\snapsave-app_1674250736978760_hd.mp4`.
5. Functional reference: [Countdown to Anything](https://apps.apple.com/ph/app/countdown-to-anything/id1489443070).

Mockup text, dates, and counts are illustrative. Production values must come from the date engine. Build original interface components and assets; screenshots are not app backgrounds.

## 2. Screens and interaction flow

### Countdowns home

- Header with the canonical logo, title, settings action, and event position.
- Selected event title and target date.
- A large calendar ticket with logo eyes, prominent total days remaining, cheeks, and one smile.
- Swipe horizontally to change selected event; show compact page position and a next-event row.
- Provide an accessible “All countdowns” list for larger collections; the carousel is not the only way to reach an event.
- Bottom navigation has Countdowns, a central add action, and Countups.
- Tapping the ticket opens the event detail view.

### Countups home

- Reuse the same structure, with elapsed days, starting date, and countup-specific language.
- Support a custom suffix such as “days together”; default to “days since”.
- Provide the same list access, event browsing, detail view, and add action.
- Preserve the selected event independently in each tab.

### Add countdown / Add countup

- The active tab determines the new event's mode; the sheet title states that mode clearly.
- Name field, year selector, month/day circular selectors, and readable selected-date summary.
- The paired date wheels use the logo's eye geometry. Small pupil accents must never obscure the selected date.
- Month/day wheels snap to valid values; the single smile connects them visually.
- Offer a standard calendar/date entry alternative for fast entry, accessibility, and distant dates.
- Countdown dates must be today or later; countup dates must be today or earlier.
- Appearance sheet: reusable illustration, theme color, and optional tag.
- Countdown recurrence: Never, Weekly, Monthly, Yearly. Countups do not have recurrence.
- Countup form includes the optional day-label field.
- Create action saves once and reveals the new event on its matching home screen.
- Keyboard, small-screen, and large-text layouts must scroll naturally; the create action remains reachable.
- Dismissing an edited draft asks whether to discard it; an untouched draft closes immediately.

### Event detail / Edit

- Expand the selected ticket into a detail presentation with the same identity and face proportions.
- Show title, exact date, total calendar days, tag, and optional note.
- Optional weeks-and-days breakdown must be derived from the same total: 18 days = 2 weeks + 4 days.
- Edit, share image, and remove actions. Removing an event provides a recovery/undo path.
- Editing reuses the creation form with populated fields and “Save changes”.
- A completed countdown stays a countdown at zero with “Today” or “Date passed”; conversion to a countup is an explicit user action.

### Supporting states

- Distinct empty states for Countdowns and Countups, each with the same logo and a clear add action.
- Finished countdown, invalid date, storage failure, and notification-denied states.
- Settings for motion/haptics, appearance, and optional notification preferences.
- No unrelated productivity features or third navigation category.

## 3. Visual system and reusable assets

Create one canonical vector face component, reused by headers, cards, date selectors, empty states, illustration faces, and milestone feedback. Do not redraw its mouth independently on each screen.

Suggested component structure:

- `BrandFace`: eyes, pupils, cheeks, single smile; size and expression parameters.
- `EventTicket`: event theme, day number, illustration, and date label.
- `DateEyeWheel`: one accessible calendar selection wheel.
- `EventDatePicker`: coordinates year, month, day, validation, and standard-picker alternative.
- `AppTabBar`, `CreateEventButton`, `EventListRow`, and `AppearancePicker`.
- Shared color, spacing, corner-radius, typography, and motion tokens.

Bundle these existing font files with their license during implementation:

```text
Z:\Git\today-tracker\assets\fonts\regular.ttf
Z:\Git\today-tracker\assets\fonts\bold.ttf
Z:\Git\today-tracker\assets\fonts\heavy.ttf
Z:\Git\today-tracker\assets\fonts\OFL.txt
```

Retain `nunito.woff2` if a future web companion needs it; the native app uses the TTF files. Inspect the actual PostScript names and weight mapping instead of guessing from filenames. Apply Dynamic Type scaling, including custom-font text. Large counts must accommodate four or more digits without clipping.

Create editable sun, gift, flower, sprout, and house illustrations using the shared face component. Keep decorative art secondary to the count and event title. Include light/dark adaptations only after the primary cream theme is settled.

## 4. Date rules and persistence

### First release date semantics

- Events are **all-day calendar dates**. Omit the earlier mockup's all-day switch until exact-time events are intentionally supported.
- Store year/month/day components rather than treating every date as a fixed UTC timestamp.
- Use the Gregorian calendar and the device's current local time zone for “today”. Recalculate on local midnight, foreground entry, date change, or time-zone change.
- Countdowns: calendar-day difference from today to the target, clamped at zero.
- Countups: calendar-day difference from the starting date to today, never a negative display.
- Same-day events show zero days, with human-readable “Today” context.
- Do not divide elapsed seconds by 86,400 to calculate all-day counts; that fails across daylight-saving changes.
- The calendar picker adapts day ranges when month/year changes. An invalid day clamps to the last valid day and is announced accessibly.
- Weekly recurrence advances in seven-calendar-day steps. Monthly recurrence uses the last day when the original day is unavailable, while retaining the original day for subsequent months.
- For a February 29 yearly event, expose a clear February 28 / March 1 non-leap-year choice; default to February 28 and display the selected policy.
- A repeating countdown displays zero on its occurrence day, then advances on the next local day.

### Event model

```text
Event
  id: UUID
  kind: countdown | countup
  title: String
  date: year / month / day
  themeID: String
  illustrationID: String
  tagID: optional UUID
  dayLabel: optional String
  note: optional String
  recurrence: none | weekly | monthly | yearly
  leapDayPolicy: optional February28 | March1
  createdAt / updatedAt: timestamps
  sortOrder: Int
```

Use a versioned local JSON store with atomic writes and explicit errors. Decode failures must not silently overwrite user data with an empty collection. Keep date calculations independent of SwiftUI so they can be tested with an injected clock/calendar. Store selected event IDs and preferences separately from event records. Cloud synchronization is a later scope decision.

## 5. Motion specification

Timing values below are starting targets, to be tuned on real hardware. Motion follows the user's action and communicates a state change.

| Interaction | Intended behavior | Initial target | Reduced-motion behavior |
| --- | --- | --- | --- |
| Change event | Ticket follows the swipe and settles; pupils glance subtly toward the incoming event | 280–360 ms settle | Short crossfade |
| Open creation | Central + expands into the creation sheet; date selectors appear in place | 320–420 ms | Standard sheet transition |
| Rotate a date wheel | Selected value snaps into the eye's center; adjacent dates fade; one light haptic per selected step | 150–220 ms settle | Immediate selection, no rotation |
| Create event | Button becomes a check; smile lifts briefly; new ticket appears on the correct tab | 400–550 ms sequence | Check confirmation, then crossfade |
| Open detail | Selected ticket expands while preserving its title and face identity | 300–400 ms | Crossfade |
| Day changes | Only changed digits transition, with a brief expression change | 220–300 ms | Replace digits immediately |
| Reach a milestone | One short celebratory expression when viewed; no looping celebration | Under 1 second | Static milestone message |

Requirements:

- Animations are interruptible and do not delay saving or navigation.
- Prevent duplicate creation during an in-progress save.
- Haptics respect user preference; no repeated haptics during programmatic updates.
- No continuous decorative movement while idle, backgrounded, or with Reduce Motion enabled.
- Avoid distorting text or morphing unrelated glyphs. Keep exactly one mouth through every transition.
- Date wheels also expose VoiceOver adjustable actions; dragging is never the only input method.
- Aim for smooth rendering on a supported physical iPhone, then measure frame pacing and energy use with Instruments.

## 6. Technical structure

```text
CountdownApp.xcodeproj
CountdownApp/
  App/                 entry point, app model, navigation
  Models/              event, recurrence, date components
  Services/            date engine, event store, notifications
  DesignSystem/        typography, colors, geometry, motion
  Components/          face, tickets, wheels, navigation
  Features/
    Countdowns/
    Countups/
    EventEditor/
    EventDetail/
    Settings/
  Resources/           fonts, license, vector assets
CountdownAppTests/     date engine and persistence tests
docs/design/           reference images and design decisions
```

Use a main-actor observable app model for UI state, explicit services for persistence and date arithmetic, and native navigation/sheet presentation. Prefer SwiftUI shape/vector drawing for the logo so it remains sharp and animatable. Add a rendering technology only when a demonstrated animation need justifies it.

This workspace is on Windows. Source preparation and static checks can happen here; Xcode compilation, simulator captures, VoiceOver checks, StoreKit testing, and physical-device profiling require a Mac/iPhone. Do not report a native build as passed until it has actually run.

## 7. Implementation milestones and acceptance gates

| Phase | Work | Done when |
| --- | --- | --- |
| 1. Foundation | Create native project, bundle fonts/license, establish tokens and canonical logo | App runs in Xcode; Nunito weights render correctly; every face uses one shared component |
| 2. Date engine and storage | Implement date rules, recurrence, event schema, atomic persistence | Deterministic date and storage tests pass; saved events survive relaunch |
| 3. Static usable app | Build both homes, list access, add/edit forms, detail, delete/undo, empty states | User can create, browse, edit, and remove both kinds of event without placeholder controls |
| 4. Signature date picker | Build calendar-eye selectors and standard-picker alternative | Valid date selection works for leap years, month boundaries, large text, and VoiceOver |
| 5. Motion and haptics | Implement the motion table with interruptibility and reduced motion | Core flows remain responsive; no double mouth or duplicate saves; physical-device performance reviewed |
| 6. Finish and accessibility | Share-card export, optional local reminders, small-screen polish, error handling | Export is legible; reminders handle permission and schedule changes; accessibility checks pass |
| 7. Submission preparation | Verify contest rules; decide business model; implement RevenueCat if appropriate; prepare screenshots, demo video, privacy/store materials | Confirmed requirements are satisfied and actual purchase/restore flows pass sandbox tests if monetization is included |

RevenueCat is not part of the core date engine. Do not invent pricing, entitlement IDs, subscription terms, or a paywall before the business model and competition requirements are confirmed. If a paid tier is chosen, preserve a useful free core and test purchases, restore, expiry, and offline entitlement behavior.

## 8. Verification checklist

- Date engine: today, tomorrow, yesterday, month/year changes, leap days, DST boundaries, time-zone changes, and recurrence rollover.
- Persistence: create/edit/remove/undo, relaunch, malformed data, write failure, and schema migration.
- UI: empty collections, one event, many events, long names, large numbers, keyboard visibility, and large accessibility text.
- Navigation: create from each tab; save returns to the matching tab and selected event; switching tabs retains selection.
- Accessibility: meaningful labels, sufficient contrast, non-color selection indicators, reachable controls, VoiceOver date selection, and Reduce Motion.
- Visual consistency: correct Nunito weights; canonical eyes/cheeks/single smile; icon faces match the logo; no leftover timer or Moments copy.
- Motion: rapid repeated taps, interrupted swipes, navigation during animations, background/foreground, and low-power behavior.
- Native validation: Xcode build, unit tests, simulator screenshots at small and large phone sizes, and at least one physical-device review.

## 9. Decisions to resolve before release

These do not block the initial product implementation:

- Final app name and bundle identifier/signing team.
- Final native build, simulator review, and physical-device validation.
- Whether the initial release needs widgets, cloud sync, exact-time events, or an iPad-specific layout; none is assumed in the core scope.
- Free versus paid features and any RevenueCat integration requirements.
- Official 2027 event name, dates, location, submission categories, and eligibility.

## Immediate next step

Open the included Xcode project on a Mac, run the unit tests and app, then perform the visual and accessibility checks in `docs/BUILD_STATUS.md`. The source contains both event flows, date-wheel controls, motion, storage, reminders, and export. Source checks are not a substitute for passing the native acceptance gates above.
