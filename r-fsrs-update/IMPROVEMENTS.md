# r-fsrs Code Analysis & Improvement Plan

## Current State Summary

**Good news:** The package is more complete than expected!

- **Rust dependency**: `fsrs = "5"` — This is the **full fsrs-rs crate** with optimizer support, not the lightweight rs-fsrs scheduler-only crate
- **R6 API**: Already has `Card`, `Scheduler`, `ReviewLog`, `Rating`, `State` — mirrors py-fsrs nicely
- **Tests**: 173 lines of solid test coverage
- **Vignette**: Well-written getting-started guide

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         R Layer                                  │
├─────────────────────────────────────────────────────────────────┤
│  fsrs_api.R (R6 Classes)          extendr-wrappers.R            │
│  ├── Card                         ├── fsrs_default_parameters() │
│  ├── Scheduler                    ├── fsrs_initial_state()      │
│  ├── ReviewLog                    ├── fsrs_next_state()         │
│  ├── Rating                       ├── fsrs_next_interval()      │
│  └── State                        └── fsrs_retrievability()     │
├─────────────────────────────────────────────────────────────────┤
│                       Rust Layer (lib.rs)                        │
│  Uses: FSRS, MemoryState, DEFAULT_PARAMETERS from fsrs crate    │
├─────────────────────────────────────────────────────────────────┤
│                       fsrs crate v5.x                            │
│  Full optimizer + scheduler (burn, rayon, ndarray...)           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Issues & Improvements

### 1. 🔴 Critical: Scheduler Doesn't Support Custom Parameters

**Problem:** The Scheduler class stores `parameters` but **never uses them** — all Rust calls use `DEFAULT_PARAMETERS`:

```rust
// lib.rs - hardcoded DEFAULT_PARAMETERS everywhere
fn fsrs_next_interval(stability: f64, desired_retention: f64) -> f64 {
    let fsrs = FSRS::new(Some(&DEFAULT_PARAMETERS)).unwrap();  // ← Always default!
    // ...
}
```

```r
# fsrs_api.R - parameters stored but unused
Scheduler$new(parameters = custom_params)  # ← parameters ignored!
```

**Fix:** Add parameters argument to all Rust functions or create an FSRS instance that can be reused.

**Option A: Pass parameters to each function**
```rust
#[extendr]
fn fsrs_next_state_with_params(
    params: Vec<f64>, 
    stability: f64, 
    difficulty: f64, 
    elapsed_days: f64, 
    rating: i32
) -> List {
    let params_f32: Vec<f32> = params.iter().map(|&x| x as f32).collect();
    let fsrs = FSRS::new(Some(&params_f32)).unwrap();
    // ...
}
```

**Option B: Create FSRS wrapper struct (better for performance)**
```rust
struct RFsrs {
    fsrs: FSRS,
}

#[extendr]
impl RFsrs {
    fn new(params: Option<Vec<f64>>) -> Self {
        let p = params.map(|v| v.iter().map(|&x| x as f32).collect::<Vec<_>>());
        Self { fsrs: FSRS::new(p.as_deref()).unwrap() }
    }
    
    fn next_states(&self, stability: Option<f64>, difficulty: Option<f64>, elapsed_days: f64) -> List {
        // ...
    }
}
```

---

### 2. 🔴 Critical: Missing Optimizer Binding

The crate has the optimizer but it's not exposed! This is the most valuable feature.

**Add to lib.rs:**
```rust
use fsrs::{compute_parameters, ComputeParametersInput, FSRSItem, FSRSReview};

#[extendr]
fn fsrs_optimize(
    ratings: Vec<i32>,      // Flattened ratings
    delta_ts: Vec<i32>,     // Flattened delta_t values  
    card_indices: Vec<i32>, // Which card each review belongs to
    // Optional training params
) -> List {
    // Convert R data to Vec<FSRSItem>
    let items = convert_to_fsrs_items(ratings, delta_ts, card_indices);
    
    let result = compute_parameters(ComputeParametersInput {
        train_set: items,
        ..Default::default()
    }).unwrap();
    
    list!(
        parameters = result.parameters.iter().map(|&x| x as f64).collect::<Vec<_>>(),
        // metrics...
    )
}
```

**R wrapper:**
```r
#' Optimize FSRS parameters from review history
#' @param reviews data.frame with card_id, rating (1-4), delta_t (days since last review)
#' @return Named list with optimized parameters
#' @export
fsrs_optimize <- function(reviews, epochs = 5, ...) {
  # Convert data.frame to flat vectors
  # Call Rust
  .Call(wrap__fsrs_optimize, ...)
}
```

---

### 3. 🟡 Medium: Missing `repeat()` Function

The `rs-fsrs` and `py-fsrs` API has a `repeat(card, now)` function that returns **all 4 rating outcomes at once**. This is useful for showing the user what each button does.

**Current approach requires 4 calls:**
```r
# Inefficient - 4 separate Rust calls
state_again <- fsrs_next_state(s, d, 1, elapsed)
state_hard  <- fsrs_next_state(s, d, 2, elapsed)
state_good  <- fsrs_next_state(s, d, 3, elapsed)
state_easy  <- fsrs_next_state(s, d, 4, elapsed)
```

**Better: Return all 4 at once**
```rust
#[extendr]
fn fsrs_repeat(stability: Option<f64>, difficulty: Option<f64>, elapsed_days: f64) -> List {
    let fsrs = FSRS::new(Some(&DEFAULT_PARAMETERS)).unwrap();
    let state = stability.map(|s| MemoryState {
        stability: s as f32,
        difficulty: difficulty.unwrap_or(5.0) as f32,
    });
    
    let states = fsrs.next_states(state, elapsed_days as f32, 0).unwrap();
    
    list!(
        again = list!(
            stability = states.again.memory.stability as f64,
            difficulty = states.again.memory.difficulty as f64,
            interval = states.again.interval as f64
        ),
        hard = list!(
            stability = states.hard.memory.stability as f64,
            difficulty = states.hard.memory.difficulty as f64,
            interval = states.hard.interval as f64
        ),
        good = list!(
            stability = states.good.memory.stability as f64,
            difficulty = states.good.memory.difficulty as f64,
            interval = states.good.interval as f64
        ),
        easy = list!(
            stability = states.easy.memory.stability as f64,
            difficulty = states.easy.memory.difficulty as f64,
            interval = states.easy.interval as f64
        )
    )
}
```

---

### 4. 🟡 Medium: Missing SM-2 Migration Helper

```rust
#[extendr]
fn fsrs_from_sm2(ease_factor: f64, interval: f64, sm2_retention: f64) -> List {
    let fsrs = FSRS::new(Some(&DEFAULT_PARAMETERS)).unwrap();
    let state = fsrs.memory_state_from_sm2(
        ease_factor as f32,
        interval as f32, 
        sm2_retention as f32
    ).unwrap();
    
    list!(
        stability = state.stability as f64,
        difficulty = state.difficulty as f64
    )
}
```

---

### 5. 🟡 Medium: Missing `memory_state()` for Review History

Compute state from a sequence of reviews (useful for importing existing data):

```rust
#[extendr]
fn fsrs_memory_state(ratings: Vec<i32>, delta_ts: Vec<i32>) -> List {
    let fsrs = FSRS::new(Some(&DEFAULT_PARAMETERS)).unwrap();
    
    let reviews: Vec<FSRSReview> = ratings.iter()
        .zip(delta_ts.iter())
        .map(|(&r, &t)| FSRSReview { rating: r as u32, delta_t: t as u32 })
        .collect();
    
    let item = FSRSItem { reviews };
    let state = fsrs.memory_state(item, None).unwrap();
    
    list!(
        stability = state.stability as f64,
        difficulty = state.difficulty as f64
    )
}
```

---

### 6. 🟢 Minor: Scheduler's `review_card()` State Transitions

**Issue:** The state transition logic doesn't fully match FSRS:

```r
# Current (simplified)
if (rating == Rating$Again) { 
  card$state <- State$Learning  # Should be Relearning if was Review
}
```

**Fix:** Follow py-fsrs/rs-fsrs state machine:
- New + Again → Learning
- New + (Hard/Good/Easy) → Review  
- Review + Again → Relearning
- Learning/Relearning + Good → Review (graduated)

---

### 7. 🟢 Minor: Add `desired_retention` to `fsrs_next_state()`

Currently `fsrs_next_state()` ignores desired retention. The interval calculation happens separately. Consider returning interval too:

```rust
#[extendr]
fn fsrs_next_state(
    stability: f64, 
    difficulty: f64, 
    elapsed_days: f64, 
    rating: i32,
    desired_retention: f64  // Add this
) -> List {
    // ...
    list!(
        stability = next.stability as f64,
        difficulty = next.difficulty as f64,
        interval = fsrs.next_interval(Some(next.stability), desired_retention as f32, 0) as f64
    )
}
```

---

### 8. 🟢 Minor: Vectorization for Performance

For analyzing Anki exports with thousands of cards, vectorized operations would help:

```rust
#[extendr]
fn fsrs_retrievability_vec(stability: Vec<f64>, elapsed_days: Vec<f64>) -> Vec<f64> {
    stability.iter()
        .zip(elapsed_days.iter())
        .map(|(s, t)| (1.0 + FACTOR * t / s).powf(DECAY))
        .collect()
}
```

---

### 9. 🟢 Minor: Documentation Improvements

Add roxygen2 `@details` with formulas:

```r
#' Calculate Memory Retrievability
#'
#' @details
#' Uses the FSRS forgetting curve formula:
#' \deqn{R(t) = \left(1 + \frac{t}{9S}\right)^{-0.5}}
#' 
#' By definition, when t = S (elapsed days equals stability), R ≈ 0.9.
#'
#' @param stability Numeric. Memory stability in days (must be > 0)
#' @param elapsed_days Numeric. Days since last review (must be >= 0)
#' @return Numeric in \[0, 1\] representing probability of recall
#' @examples
#' # 90% recall probability at stability days
#' fsrs_retrievability(10, 10)  # ≈ 0.9
#' @export
```

---

### 10. 🟢 Minor: Add Tests for R6 Classes

Current tests only cover low-level functions. Add tests for `Card`, `Scheduler`:

```r
test_that("Scheduler.review_card updates card correctly", {
  scheduler <- Scheduler$new()
  card <- Card$new()
  
  result <- scheduler$review_card(card, Rating$Good)
  
  expect_s3_class(result$card, "Card")
  expect_s3_class(result$review_log, "ReviewLog")
  expect_true(result$card$stability > 0)
  expect_equal(result$card$reps, 1L)
  expect_equal(result$card$state, State$Review)
})

test_that("Card.get_retrievability works", {
  card <- Card$new()
  scheduler <- Scheduler$new()
  scheduler$review_card(card, Rating$Good)
  
  Sys.sleep(0.1)  # Small delay
  r <- card$get_retrievability()
  expect_true(r > 0 && r <= 1)
})
```

---

## Implementation Priority

### Phase 1: Fix Critical Issues
1. **Custom parameters support** — Users can't use optimized params yet
2. **Add `fsrs_repeat()`** — Standard API pattern

### Phase 2: Add Optimizer
3. **`fsrs_optimize()`** — The killer feature
4. **`fsrs_memory_state()`** — Bulk state computation
5. **`fsrs_from_sm2()`** — Migration helper

### Phase 3: Polish
6. Fix state transitions in `Scheduler`
7. Add vectorized functions
8. Improve documentation
9. Add R6 class tests

---

## Quick Win: Fix Custom Parameters

This is the most impactful change you can make quickly. Here's the minimal diff:

**lib.rs:**
```rust
#[extendr]
fn fsrs_next_state_params(
    params: Vec<f64>,  // NEW
    stability: f64, 
    difficulty: f64, 
    elapsed_days: f64, 
    rating: i32
) -> List {
    let params_f32: Vec<f32> = params.iter().map(|&x| x as f32).collect();
    let fsrs = FSRS::new(Some(&params_f32)).unwrap();
    // ... rest same
}
```

**fsrs_api.R:**
```r
# In Scheduler$review_card():
if (card$state == State$New) {
  new_state <- fsrs_initial_state_params(self$parameters, rating)  # Use params
  # ...
} else {
  new_state <- fsrs_next_state_params(self$parameters, card$stability, ...)
}
```

---

## Summary

| Issue | Severity | Effort | Impact |
|-------|----------|--------|--------|
| Custom params not used | 🔴 Critical | Low | High |
| Optimizer not exposed | 🔴 Critical | Medium | Very High |
| No `repeat()` function | 🟡 Medium | Low | Medium |
| No SM-2 migration | 🟡 Medium | Low | Medium |
| No batch memory_state | 🟡 Medium | Medium | Medium |
| State transitions | 🟢 Minor | Low | Low |
| Vectorization | 🟢 Minor | Low | Medium |
| Documentation | 🟢 Minor | Low | Low |

The package has a solid foundation! The R6 API is well-designed and mirrors py-fsrs. The main gaps are:
1. Custom parameters don't actually work
2. The optimizer (which you already have via fsrs crate) isn't exposed

Want me to write the actual Rust code for any of these improvements?
