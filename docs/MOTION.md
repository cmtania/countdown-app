# Motion implementation

Motion communicates selection, completion, and navigation. It never changes stored dates or delays a save transaction.

| Area | Source implementation |
| --- | --- |
| Date wheels | Stable month/day labels slide vertically through a faded window, growing and darkening as they reach the center. Drag or tap a neighboring value; release snaps to the closest value with a 300 ms response spring (0.86 damping). Tick marks rotate with selection and drag, and pupils follow the gesture slightly. Boundaries resist overscroll; there is no momentum that skips dates. One selection haptic per changed value. Canceled gestures clear their drag offsets. |
| Eye expression | A short glance after event selection, followed by a return to rest. No idle animation loop. |
| Smile | One reusable curve with gold outer stroke and inset orange stroke. A small lift accompanies a viewed occurrence-day milestone. |
| Day numbers | Numeric content transitions, with a 250 ms ease-in-out animation when the count changes. |
| Save | Atomic save first, then checkmark and brief smile lift; dismissal follows. Duplicate submissions are disabled. |
| Browsing | Native page interaction with explicit list and next/previous alternatives. |
| Creation | The orange add button expands into the editor using its measured screen bounds. The full-size form fades in through a moving mask; text does not scale. |
| Detail | The selected ticket's surface expands into the detail view and contracts on close. Settings and secondary editors use native sheets. |

Reduce Motion or the in-app Gentle Motion setting suppresses the custom springs, eye movement, number animation, and save delay. Native system presentation follows the system accessibility behavior. Haptics have a separate preference.

Month/day selection uses the same live date bindings for drag, neighbor taps, and VoiceOver adjustments. Changing the month or year still clamps an invalid day to that month's last day; the day wheel animates that resulting selection too. At accessibility text sizes, the standard calendar remains available instead of the circular wheels.

The surface transitions live in `ExpandingPanel.swift`. Underlying controls are inaccessible while a panel is open. Close requests animate before dismissing the panel; Reduce Motion skips the expansion and reveal delays. A changed editor requires an explicit discard decision. The reference timings remain starting points until native layout and device profiling are available.

Before release, inspect interactions with VoiceOver, Reduce Motion, large text, rapid repeated actions, interruptions, backgrounding, and on the oldest supported phone. Confirm that dates remain legible throughout every transition and that all faces still have one mouth.
