# r-fsrs Update Instructions

## What's Changed

### 1. `src/rust/src/lib.rs`
- All functions now accept optional `params` argument for custom parameters
- Added `fsrs_repeat()` — returns all 4 rating outcomes at once
- Added `fsrs_from_sm2()` — SM-2 migration helper
- Added `fsrs_memory_state()` — compute state from review history
- Added `fsrs_retrievability_vec()` — vectorized version for performance
- Optimizer binding is scaffolded but commented out (see below)

### 2. `R/fsrs_api.R`
- `Scheduler` now actually uses custom parameters (was ignoring them!)
- Added `preview_card()` method to see all 4 outcomes
- Fixed state transitions to match py-fsrs/rs-fsrs
- Added `clone_card()` method to Card
- Added `fsrs_simulate()` convenience function

## How to Apply

```bash
# 1. Extract and copy files
unzip r-fsrs-update.zip
cp -r r-fsrs-update/src/rust/src/lib.rs ~/r-fsrs/src/rust/src/lib.rs
cp -r r-fsrs-update/R/fsrs_api.R ~/r-fsrs/R/fsrs_api.R

# 2. Regenerate R wrappers (in R)
# This creates R/extendr-wrappers.R from the Rust code
setwd("~/r-fsrs")
rextendr::document()

# 3. Rebuild and test
R CMD build .
R CMD check rfsrs_*.tar.gz

# 4. Commit
git add -A
git commit -m "Add custom parameter support, fsrs_repeat, SM-2 migration, memory_state

- All Rust functions now accept optional params argument
- Scheduler actually uses custom parameters (was broken)
- fsrs_repeat() returns all 4 rating outcomes at once
- fsrs_from_sm2() for SM-2 migration
- fsrs_memory_state() computes state from review history
- fsrs_retrievability_vec() for vectorized operations
- Fixed state transitions in Scheduler
- Added preview_card() and clone_card() methods"

git push
```

## Breaking Changes

The low-level functions now have an additional `params` argument:
```r
# Old (still works - params defaults to NULL which uses defaults)
fsrs_next_state(stability, difficulty, elapsed_days, rating)

# New (explicit custom params)
fsrs_next_state(stability, difficulty, elapsed_days, rating, params = my_params)
```

## Enabling the Optimizer (Future)

To enable `fsrs_optimize()`, edit `src/rust/Cargo.toml`:
```toml
[dependencies]
fsrs = { version = "5", features = ["bundled-train"] }
```

Then uncomment the optimizer code in `lib.rs` and `extendr-wrappers.R`.

**Warning:** This significantly increases compile time (~5-10 minutes) and binary size.

## New API Summary

| Function | Description |
|----------|-------------|
| `fsrs_repeat(S, D, elapsed, retention, params)` | Get all 4 outcomes at once |
| `fsrs_from_sm2(ease, interval, retention, params)` | Convert SM-2 to FSRS state |
| `fsrs_memory_state(ratings, delta_ts, ...)` | Compute state from history |
| `fsrs_retrievability_vec(S, elapsed)` | Vectorized retrievability |
| `Scheduler$preview_card(card)` | Preview without modifying |
| `Card$clone_card()` | Deep copy a card |
| `fsrs_simulate(ratings, params, retention)` | Simulate learning |
