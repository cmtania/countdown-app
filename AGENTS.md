# Repository workflow

- Automatically commit completed changes in this repository after appropriate checks. The user explicitly requested this; do not ask for commit confirmation.
- Commit only changes belonging to the current task. Preserve unrelated user work.
- Do not push unless the user requests it.
- Keep generated Xcode signing settings consistent with `scripts/generate-project.mjs`.
- Report source checks separately from native compilation and XCTest execution. Native checks require a working Swift/Xcode environment.
