# ORIENT

## Purpose

- Center an active editing window with two non-focusable decorative splits.
- Preserve usable layout through tab switches, source changes, pad loss,
  ignored contexts, session persistence, and delayed callbacks.
- Complement agent guidance; focus on architectural boundaries and contracts.

## Evidence scope

- README, public surface, core modules, and regression specs supply evidence.
- No ADR or design corpus surfaced.
- Findings follow source-and-test synthesis rather than declared design records.

## Architectural shape

- Thin public façade:
  - Merges shared option defaults.
  - Defers plugin loading until user invocation.
  - Forwards public requests into one coordinator.
- Coordinator:
  - Owns validation, ordering, topology mutation, width handling, cleanup,
    re-enable transitions, and option snapshots.
  - Injects callbacks into event handling; avoids reverse coordinator imports.
- Axis modules:
  - State routes current-tab proxy fields plus owner-targeted access.
  - Window constructs pads and preserves local visual state.
  - Autocmds own lifecycle groups, timers, recovery, context tracking,
    startup deferral, and session choreography.
  - Enabled centralizes tab-local-to-global mirroring.
  - Health observes and reports contracts without normal behavioral mutation.
- Tabpage boundary:
  - Pad identity, option snapshot, source-option capture, restore timer,
    tracker intent, lifecycle group, and event ownership follow one tab.

## Boundary map

| Boundary | Owns | Leaves elsewhere |
| :-- | :-- | :-- |
| Public façade and plugin loader | Shared defaults, exported calls, deferred load | Layout mutation and event registration |
| Coordinator | Enable/disable/toggle, request guards, resize-or-rebuild sequencing | Low-level window mechanics and autocmd creation |
| State | Per-tab stores, proxy routing, owner access, timer references, diagnostics | Editor UI mutation |
| Window | Pad buffers/windows, pad markers, tracked-ID cleanup, local options | Lifecycle policy |
| Autocmds | Per-tab groups, persistent tracker, owner guards, debounce, recovery, session hooks | Public option ownership |
| Enabled and health | Global bridge, legacy compatibility reads, diagnostics | Pad construction and cleanup |

## State and identity

- `pad_state` carries main, left, right, and enabled identities per tab.
- Pad buffers carry Centerpad and side markers; tracked window IDs drive
  destructive cleanup.
- Window scans support validation and recovery only; cleanup follows tracked
  IDs rather than topology guesses.
- Per-tab option snapshots decouple recovery and resume from later shared
  default mutation.
- Captured source options preserve explicit local `fillchars` versus inherited
  `fillchars` after cleanup or source replacement.
- Tracker opt-in, suspension, config copy, and debounce timer gate automatic
  resume; manual disable clears that authority.
- One persistent tracker group carries cross-tab bridge work; per-tab groups
  carry pad lifecycle callbacks.
- The enabled bridge alone writes internal enabled truth and primary/legacy
  globals; tab entry remirrors active-tab truth.

## Lifecycle flows

### Setup and enable

- Setup merges user options; default mode arms a one-shot eligible `FileType`
  trigger rather than splitting an empty startup buffer.
- That trigger survives ignored contexts and disarms only after successful
  enable.
- Enable rejects ignored buffers and floating windows before topology changes.
- Enable starts with full reset, then captures the source, creates both pads,
  snapshots options, wires handlers, applies source-local `fillchars`, mirrors
  enabled truth, and schedules validation.
- Partial pad creation or source styling failure routes through coordinator
  cleanup.

### Resize and contextual tracking

- Argument parsing finishes before context checks or shared option mutation.
- Healthy pads resize in place; missing or corrupt pads route through enable.
- Floating focus produces no tracker action.
- Ignored or pad context suspends only a stable enabled layout.
- Resume requires prior tracker opt-in, suspension, stored options, and absent
  pads; manual disable prevents surprise revival.

### Recovery and teardown

- Pad entry reapplies explicit local blank chrome, then redirects focus only
  toward a valid source.
- Owner guards fence `WinClosed`, debounce callbacks, and tracker callbacks
  from sibling-tab effects.
- Pad-close detection precedes ignored-context filtering.
- Debounced recovery switches into the owner tab, validates source/pad metadata
  and widths, swaps source `fillchars` atomically, otherwise resets then
  schedules re-enable.
- Recovery restores prior tab and window when validity permits.
- Tab entry remirrors enabled globals and repairs background-tab pad-width
  drift.
- Full reset clears owner tracker callbacks before pad deletion; cleanup stops
  restoration, clears lifecycle callbacks, deletes tracked pads, restores the
  captured source when ownership survives, then clears enabled truth.

### Startup and session lifecycle

- `SessionLoadPre` disarms pending default enable and resets the current
  layout before session commands reshape windows.
- `SessionLoadPost` conditionally starts default layout after session loading.
- `PersistedSavePre` temporarily removes pads only when blank windows would
  enter saved session topology; `PersistedSavePost` rebuilds them afterward.
- Session save handling suppresses intermediary redraw, then restores final
  layout presentation.
- Startup and session hooks share the persistent tracker group, preventing a
  session script from racing the default-enable listener.

## Architectural invariants

- Guard tab ownership before callback effects; restore prior user context after
  owner-targeted asynchronous work.
- Clear per-tab lifecycle callbacks before destructive pad cleanup; retain the
  persistent tracker group for sibling tabs.
- Keep `fillchars`, statusline, and winbar changes window-local.
- Capture source-local styling before override; restore only that captured
  source.
- Avoid empty local statusline or winbar values; global-local fallback would
  leak user chrome into pads.
- Route global enabled writes through the enabled bridge.
- Validate every width request before shared-option or layout mutation.
- Prefer tracked IDs for deletion and pad markers for identification.
- Reject floating or pad windows as source candidates.
- Coordinate session additions with deferred default enable and tracker
  ownership.

## Extension seams

- New ignore rules: align coordinator guards, close-event filters, and tracker
  predicates.
- New pad visuals: extend window-local setup plus validation coverage.
- New per-tab state: add store fields, proxy access, owner-targeted helpers,
  and cleanup semantics together.
- New recovery policy: retain event ownership inside autocmds; pass coordinator
  callbacks inward.
- New public compatibility state: centralize bridges inside enabled, then
  expose diagnostics through health.
- New session integration: preserve startup-listener disarming, owner guards,
  and topology cleanup ordering.
