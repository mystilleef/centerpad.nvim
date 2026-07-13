# ORIENT

## Purpose

- Ground changes in `Centerpad` layout, recovery, and per-tab contracts.
- Complement agent guidance; skip style, commands, and test gates.

## Evidence scope

- Source modules, README/help, and regression specs ground claims.
- No ADR/design-doc corpus found; inferred claims note source/test
  synthesis.

## Architectural shape

- Thin façade plus coordinator: public `APIs` merge `config` and
  dispatch; command loader lazy-requires public surface.
- Coordinator owns sequencing: guard -> cleanup -> pad creation/resize
  -> `autocmd` wiring -> enabled mirror -> scheduled validation.
- Helper modules own one axis: per-tab state, window lifecycle/metadata,
  event recovery/tracking, enabled `globals`, health diagnostics.
- `Tabpage` as primary boundary: state proxies, lifecycle `augroups`,
  timers, trackers, `config` snapshots, and recovery callbacks all
  resolve through current/owner tab context.
- Shared `config` object drives user defaults, while per-tab `config`
  snapshots stabilize recovery/resume after later width/`config`
  mutation.

## Module boundaries

- `init`:
  - Merges `config`.
  - Forwards enable/disable/toggle/run/debug/state calls.
  - Avoids pad/window mutation.
- `plugin`:
  - Registers editor command.
  - Routes opts through public API.
  - Defers module load.
- `centerpad`:
  - Validates contexts and widths.
  - Coordinates enable/disable/toggle/run.
  - Chooses in-place resize versus recreate.
- `state`:
  - Exposes transparent tab-scoped proxies for `pad_state`, `tracker`,
    `config_snapshot`, and `source_options`.
  - Lazily prunes closed tabs.
  - Owns debug logging and validation.
- `window`:
  - Creates pad buffers/windows, applies blank UI options, marks pad
    metadata, resizes/deletes tracked pads.
  - Applies and clears window-local `fillchars`.
- `autocmds`:
  - Owns per-tab lifecycle `augroups`, persistent tracker group, focus
    redirection, `WinClosed` recovery, context suspend/resume, cleanup
    choreography.
- `enabled`:
  - Provides the single seam for internal enabled flag plus new/legacy
    public `globals`.
  - Handles legacy-only reads for diagnostics.
- `health`:
  - Reports current-tab health and global consistency.
  - Avoids behavioral side effects beyond legacy-global read path.

## Control flow

- Setup:
  - Merge `config`.
  - Optional default enable enters the same coordinator path.
- Enable:
  - Reject ignored filetypes/buftypes and floating windows before
    mutation.
  - Disable existing layout, clear lifecycle `autocmds`, delete tracked
    pads, clear leaked source-window fix options.
  - Track source window, create left/right pads, clean partial creation
    through disable, snapshot `config` per tab.
  - Wire pad-focus redirects and owner-tab recovery, apply source
    `fillchars` locally, mirror enabled `globals` true, schedule
    validation.
  - Install context tracker only after both pads survive.
- Width command:
  - Parse and bound-check every argument before context check and
    `config` mutation.
  - For healthy pads, update snapshot and resize in place.
  - For missing/corrupt pads or stale source, recreate through enable.
  - `Invalid` input leaves `config`, pads, `autocmds`, `globals`, and
    timers untouched.
- Disable:
  - Stop restore timer, clear current-tab lifecycle `autocmds`, delete
    tracked pads, clear source `fillchars` if owner tab survives, mirror
    enabled `globals` false.
  - Clear current-tab tracker opt-in/`config`/suspended flag; leave
    persistent tracker group intact.

## State and identity

- `state.pad_state` provides authoritative current-tab identity:
  **main_win**, `left_win`, `right_win`, `enabled`.
- Pad buffer vars (`is_centerpad`, `pad_side`) distinguish pad windows
  from user windows; tracked IDs drive destructive cleanup.
- Window scans support validation and recovery evidence only; cleanup
  trusts tracked IDs.
- `state.config_snapshot` decouples recovery/resume widths from later
  shared `config` changes.
- `state.source_options` carries captured source-window `fillchars` per
  tab so cleanup restores original local semantics after source switches.
- `state.tracker` gates automatic resume; missing opt-in or manual
  disable prevents surprise re-enable.
- `enabled.set()` alone updates internal flag and both `globals`;
  `TabEnter` `remirrors` active-tab truth.
- Legacy global compatibility lives in `enabled.read_globals()`; keep
  migration logic out of coordinator and health callers.
- `Fillchars` changes stay window-local; no global `fillchars`
  save/restore cycle participates.

## Recovery model

- Pad `BufEnter` reasserts blank `statusline`/`winbar`, then redirects
  focus to valid source only.
- Recovery `autocmds` carry owner-tab guards; cross-tab `WinClosed`
  noise returns early.
- Pad-buffer close detection runs before ignored `buftype`/`filetype`
  filters.
- Normal source `WinClosed` events `debounce` through per-tab restore
  timer.
- `Debounced` callback switches to owner tab, refreshes source from
  non-floating non-pad current window, validates pad metadata and
  widths, then preserves stable layout or recovers through cleanup plus
  scheduled enable.
- Scheduled recovery restores prior active tab/window when possible.
- Context tracker debounces `BufEnter`/`WinEnter`; ignored/floating/pad
  contexts suspend pads, valid source contexts resume only from prior
  suspension with stored `config`.
- Unsafe state converges through cleanup before re-enable; one-sided
  pads should never persist.

## Architectural traps

- Don't mutate `state.pad_state` or sibling proxy state from arbitrary
  callbacks; switch or guard tab context first.
- Don't clear `trackergroup` during disable; sibling tabs rely on
  owner-guarded persistent callbacks.
- Don't delete pads while lifecycle `autocmds` remain armed; cleanup
  clears group first to avoid self-triggered recovery.
- Don't touch global `vim.go.fillchars`; source and pads rely on
  window-local overrides.
- Don't restore source `fillchars` after destructive pad deletion; capture
  owner source first so sibling-tab proxies never receive writes.
- Don't assign empty local statusline/winbar to pads; global-local
  fallback leaks user UI.
- Don't update shared `config` widths before every argument and context
  validation passes.
- Don't recreate healthy pads for width changes; tests preserve pad ID
  stability.
- Don't treat current window as source until non-floating and non-pad
  checks pass.
- Don't let ignored-buffer filters hide pad closures; check pad markers
  first.
- Don't place legacy global handling outside `enabled`.
- Don't let recovery `callbacks` act across tabs; owner-tab guards and
  tab restoration protect user focus.
- Don't auto-resume after manual disable or on never-enabled tabs.

## Extension seams

- New ignore rules: update coordinator guard, recovery filters, and
  tracker context predicate together.
- New pad visuals: adjust window option/`fillchars` configuration plus
  validation specs.
- New per-tab state: add fields in `new_store()` and expose through
  proxies/timer helpers rather than module `globals`.
- New recovery heuristics: keep event logic in `autocmds`; inject
  coordinator callbacks instead of importing coordinator.
- New public compatibility state: centralize in `enabled`, then report
  from health.
- New diagnostics: read current-tab proxies; avoid mutation except
  documented sync bridges.
