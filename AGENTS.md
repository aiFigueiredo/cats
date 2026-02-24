## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills installed for this project context.

### Available skills
- composable-architecture: Use when building features with TCA (The Composable Architecture), structuring reducers, managing state, handling effects, navigation, or testing TCA features. (file: /Users/jfigueiredo/.codex/skills/composable-architecture/SKILL.md)
- swift-testing: Use when writing tests with Swift Testing (`@Test`, `#expect`, `#require`), migrating from XCTest, implementing async tests, or parameterizing tests. (file: /Users/jfigueiredo/.codex/skills/swift-testing/SKILL.md)
- axiom-ios-testing: Use for any iOS testing-related work, including unit tests, UI tests, flaky test debugging, speed improvements, and Swift Testing vs XCTest choices. (file: /Users/jfigueiredo/.codex/skills/axiom-ios-testing/SKILL.md)
- ios-simulator-skill: Use for iOS simulator automation including app launch, semantic UI navigation, screen mapping, accessibility audits, simulator lifecycle control, and scripted device interactions. (file: /Users/jfigueiredo/.codex/skills/ios-simulator-skill/SKILL.md)
- e2e-testing-patterns: Use when implementing or debugging end-to-end tests, defining E2E standards, and improving reliability of critical user-flow test suites. (file: /Users/jfigueiredo/.codex/skills/e2e-testing-patterns/SKILL.md)

### How to use skills
- Discovery: The list above is the skills available in this project context (name + description + file path). Skill bodies live on disk at the listed paths.
- Trigger rules: If the user names a skill (with `$SkillName` or plain text) OR the task clearly matches a skill's description shown above, you must use that skill for that turn. Multiple mentions mean use them all. Do not carry skills across turns unless re-mentioned.
- Missing/blocked: If a named skill is not in the list or the path cannot be read, say so briefly and continue with the best fallback.
- How to use a skill (progressive disclosure):
  1. After deciding to use a skill, open its `SKILL.md`. Read only enough to follow the workflow.
  2. When `SKILL.md` references relative paths (for example `scripts/foo.py`), resolve them relative to the skill directory listed above first, and only consider other paths if needed.
  3. If `SKILL.md` points to extra folders such as `references/`, load only the specific files needed for the request; do not bulk-load everything.
  4. If `scripts/` exist, prefer running or patching them instead of retyping large code blocks.
  5. If `assets/` or templates exist, reuse them instead of recreating from scratch.
- Coordination and sequencing:
  - If multiple skills apply, choose the minimal set that covers the request and state the order you will use them.
  - Announce which skill(s) you are using and why (one short line). If you skip an obvious skill, say why.
- Context hygiene:
  - Keep context small: summarize long sections instead of pasting them; only load extra files when needed.
  - Avoid deep reference-chasing: prefer opening only files directly linked from `SKILL.md` unless blocked.
  - When variants exist (frameworks, providers, domains), pick only the relevant reference file(s) and note that choice.
- Safety and fallback: If a skill cannot be applied cleanly (missing files, unclear instructions), state the issue, pick the next-best approach, and continue.

### Project routing
- TCA features, reducers, effects, dependency injection, and navigation: start with `composable-architecture`.
- Unit tests and async test patterns in Swift: start with `axiom-ios-testing`, then follow to `swift-testing` when writing concrete tests.
- Simulator-driven flows, app interaction, UI snapshots, and device automation: use `ios-simulator-skill`.
- E2E integration strategy and flaky E2E debugging: use `e2e-testing-patterns`.

### Current project notes
- `BreedDetailView` is the single detail entry point and has two initialization modes:
  1. Live mode (`breedID + breedsStore + selectedTab`) for breeds-tab synchronization.
  2. Standalone mode (`state + callback`) for favorites navigation.
- Cross-tab favorite synchronization currently depends on `AppView.handleTabSelection` and favorites-state change propagation.
- `ImageLoadService` is actor-based and owns in-memory cache, in-flight task deduplication, and cancellation by subscriber id.

### Regression learnings (do not regress)
- Keep favorites remove button outside `NavigationLink` tap area in `FavoritesView` rows. Nesting the button inside the link causes tap conflicts and stale state symptoms.
- When changing tab-sync logic, verify detail state updates after removing a favorite from Favorites and switching back to Breeds.
- Preserve `RemoteImageView` `activeURL` guard and `CatAPIClient.fetchBreedImage` breed-id mismatch guard to prevent wrong-image assignment.

### Required verification after related changes
- If touching favorites/detail/tab-sync flows, run:
  - `xcodebuild -scheme gato -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:gatoUITests/gatoUITests/testBreedDetailFavoriteStateRefreshesAfterRemovingInFavoritesTab test -derivedDataPath /tmp/gato-dd CODE_SIGNING_ALLOWED=NO`
- If touching image loading, run `ImageLoadServiceTests` and `CatAPIClientTests`.

### Secrets and config policy
- Never commit secrets.
- Do not track xcconfig files in source control (`*.xcconfig*` is ignored).
- Keep local-only API configuration in `Config/*.xcconfig*` and CI secrets in environment variables.
