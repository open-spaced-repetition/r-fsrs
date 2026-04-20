# rfsrs 0.3.2

## Breaking changes

* Direct Rust bindings are now internal. Previously-exported
  `fsrs_default_parameters()`, `fsrs_initial_state()`,
  `fsrs_next_state()`, `fsrs_next_interval()`, `fsrs_retrievability()`
  are renamed with a `_raw` suffix and no longer in the NAMESPACE.
  Use the validated wrappers instead: `fsrs_parameters()`,
  `fsrs_new_card_state()`, `fsrs_next_memory_state()`,
  `fsrs_interval()`, `fsrs_recall_probability()`. Direct callers
  can still reach the bindings via `rfsrs:::fsrs_*_raw`, but these
  are not a stable API.

## Documentation

* README Low-Level table reduced to the validated wrappers only.

# rfsrs 0.3.1

## Bug Fixes

* `fsrs_next_memory_state()` / `fsrs_repeat()`: fractional `elapsed_days`
  now rounds at the Rust FFI boundary instead of truncating.
  `elapsed_days = 0.7` used to collapse to 0, giving R = 1.
* `fsrs_anki_to_reviews()`: accepts `rid` and `review_type` column
  names used by `ankiR::anki_revlog()`.
* `fsrs_version()`: returns `"FSRS-6"`. Default parameters have always
  used `FSRS6_DEFAULT_DECAY = 0.1542` (fsrs-rs 5.2.0
  `DEFAULT_PARAMETERS[20]`).
* `fsrs_evaluate()` / `fsrs_optimize()`: skip items whose current
  review has `delta_t == 0`. R = 1 exactly makes `log(1 - R)` diverge,
  which returned `log_loss = NaN`.

## Documentation

* README: Anki import example now uses `anki_revlog()` instead of the
  non-existent `read_anki()`.
* README: forgetting-curve formula matches fsrs-rs:
  `R(t) = (1 + factor · t/S)^(-decay)`, `factor = 0.9^(1/-decay) - 1`.
* README: Low-Level Functions table split into validated R wrappers
  and direct Rust bindings.

# rfsrs 0.1.0

* Initial release
* R bindings for fsrs-rs Rust library via rextendr
* Core functions:
  - `fsrs_default_parameters()`: Get FSRS-6 default parameters (21 values)
  - `fsrs_initial_state()`: Create initial memory state for new cards
  - `fsrs_next_state()`: Calculate memory state after a review
  - `fsrs_next_interval()`: Get optimal interval for next review
  - `fsrs_retrievability()`: Calculate probability of recall
* Supports all four FSRS ratings (Again, Hard, Good, Easy)
* Available on r-universe: https://chrislongros.r-universe.dev
* Builds successfully on Linux and macOS (Windows builds pending)
