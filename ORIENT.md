# ORIENT

## Purpose

- Ground agent changes in `Centerpad` window-layout architecture.
- Complement local agent guidance; skip style and gate detail.

## Evidence scope

- Source, help docs, README, and regression specs ground claims.
- No Architecture Decision Record (ADR) corpus found; claims below carry
  inferred status unless a subsystem name points to source.

## Architectural pattern

- Thin façade plus coordinator.
- Public surface forwards to coordinator; editor loader defers require
  until entrypoint use.
- Coordinator sequences guard -> cleanup -> window mutation -> autocmd
  wiring -> state/global sync -> scheduled validation.
- Helper modules own one axis: state, window lifecycle, event recovery,
  enabled-global synchronization, diagnostics.

## Module boundaries

- `init`:
  - Owns user config merge and public API.
  - Delegates behavior; avoids direct state/window mutation.
- `plugin`:
  - Exposes editor entrypoint and routes options to public API.
- `centerpad` coordinator:
  - Coordinates enable, disable, toggle, argument handling, validation,
    resize/recreate decisions.
  - Mutates config widths only after argument and context validation.
- `window`:
  - Creates, configures, identifies, resizes, and deletes pad
    windows/buffers.
  - Owns pad buffer metadata and blank visual option set.
- `state`:
  - Holds mutable window IDs, enabled flag, saved visual setting,
    restore debounce timer, debug flag.
  - Supplies validation and debug logging; performs no window cleanup
    itself.
- `autocmds`:
  - Owns autocmd group, focus redirection, close-event recovery, and
    full cleanup choreography.
- `enabled`:
  - Synchronizes internal enabled flag with public globals plus
    one-release legacy bridge.
- `health`:
  - Reports module load, state validity, globals, pending recovery,
    debug status.
  - Limit changes to diagnostic/sync effects from enabled-global read
    path.

## Control flow

- Setup:
  - Merge supplied options into module config.
  - Optional default enable follows same public enable path.
- Toggle/enable:
  - Reject ignored filetypes/buftypes and floating windows before layout
    mutation.
  - Clear existing autocmds and pads, save visual setting, clear leaked
    pad-local options from source window.
  - Track current source window, create left/right pads, wire
    focus/recovery autocmds, update enabled globals, schedule
    validation.
  - Partial pad creation triggers cleanup and clears `main_win`; no
    half-enabled state should survive.
- Width request:
  - Validate all args and context before config mutation.
  - Resize healthy pads in place; recreate only after invalid tracked
    pads or stale source state.
  - Invalid args preserve config, pads, autocmds, globals, timer.
- Disable/cleanup:
  - Stop restore timer, clear autocmd group, delete tracked pads,
    restore saved visual setting, sync enabled globals false.

## State and identity

- `state.pad_state` supplies authoritative window identity: `main_win`,
  `left_win`, `right_win`, `enabled`.
- Pad buffer marker plus side metadata distinguish pad buffers from user
  buffers.
- Window scans support validation/evidence only; tracked IDs drive
  destructive cleanup.
- `enabled.set()` alone should update internal flag and both public
  globals.
- Legacy global reads live in `enabled.read_globals()`; avoid duplicate
  compatibility logic.
- Saved visual setting follows acquire-on-enable, restore-on-cleanup
  cycle; keep additional globals inside same save/restore discipline.

## Recovery model

- Pad `BufEnter` redirects to tracked source window only when valid;
  invalid source window leaves focus alone and lets close recovery
  rebuild.
- Close recovery handles pad-buffer closures before ignored buffer
  filters; pad buffers use ignored `buftype`.
- Normal source `WinClosed` events debounce through
  `state.restore_timer`.
- Debounced recovery refreshes source identity from current non-floating
  non-pad window, validates pad IDs/markers/widths, then either
  preserves layout or runs cleanup plus scheduled enable.
- Stable unrelated split closure must not rebuild pads or change pad
  IDs.
- Unsafe state must converge through `autocmds.cleanup()` before any
  re-enable.

## Architectural traps

- Do not mutate `state.pad_state` from callers; use
  coordinator/window/autocmd/enabled seams.
- Do not delete pads while recovery autocmds remain armed; cleanup
  clears group first to avoid self-triggered rebuild.
- Do not recreate pads for healthy width changes; identity stability has
  user-visible and test-backed semantics.
- Do not treat any current window as source until non-floating and
  non-pad checks pass.
- Do not place legacy-global handling in coordinator or health; keep
  bridge centralized.
- Do not use empty local statusline/winbar for pads; global-local
  fallback would leak user UI into padding.
- Do not update config widths before every validation succeeds; invalid
  input must preserve layout and config.
- Do not let pad closure, stale main window, or corrupted marker leave
  one-sided pads; recovery should cleanup then rebuild.

## Extension seams

- New ignore-context logic belongs in coordinator guard plus close-event
  source filters.
- New pad visual rules belong in window option set and validation specs.
- New public state compatibility belongs in enabled module, then health
  can report it.
- New recovery heuristics belong inside autocmds, with state/window
  helpers kept side-effect narrow.
