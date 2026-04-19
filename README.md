# rfsrs

<!-- badges: start -->
[![R-CMD-check](https://github.com/open-spaced-repetition/r-fsrs/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/open-spaced-repetition/r-fsrs/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

R bindings for [fsrs-rs](https://github.com/open-spaced-repetition/fsrs-rs), the Rust implementation of the Free Spaced Repetition Scheduler (FSRS) algorithm.

FSRS is a modern spaced repetition algorithm based on the DSR (Difficulty, Stability, Retrievability) model of memory. It uses 21 optimizable parameters to predict optimal review intervals more accurately than traditional algorithms like SM-2.

## Features

- **Full FSRS-6 implementation** via Rust bindings
- **Parameter optimization** — train custom parameters from your review history
- **SM-2 migration** — convert from Anki's default algorithm
- **High performance** — Rust-powered core with R6 convenience classes

## Installation

```r
# Install Rust first: https://rustup.rs

# From GitHub
remotes::install_github("open-spaced-repetition/r-fsrs")

# From r-universe
install.packages("rfsrs", repos = "https://chrislongros.r-universe.dev")
```

## Quick Start

### Basic Scheduling

```r
library(rfsrs)

# Create a scheduler
scheduler <- Scheduler$new(desired_retention = 0.9)

# Create and review a card
card <- Card$new()
result <- scheduler$review_card(card, Rating$Good)
print(card)
```

### Parameter Optimization

Train custom parameters from your review history for better scheduling accuracy:

```r
# Prepare your review data
reviews <- data.frame(
  card_id = c(1, 1, 1, 2, 2, 2, ...),
  rating = c(3, 3, 4, 2, 3, 3, ...),  # 1=Again, 2=Hard, 3=Good, 4=Easy
  delta_t = c(0, 1, 3, 0, 2, 5, ...)   # Days since previous review
)

# Optimize parameters
result <- fsrs_optimize(reviews)

if (result$success) {
  # Use optimized parameters
  my_scheduler <- Scheduler$new(parameters = result$parameters)
}
```

### Import from Anki

```r
# With the ankiR package
library(ankiR)
revlog <- anki_revlog()  # auto-detects the default profile
reviews <- fsrs_anki_to_reviews(revlog)

# Optimize
result <- fsrs_optimize(reviews)

# Compare accuracy
default_metrics <- fsrs_evaluate(reviews, NULL)
custom_metrics <- fsrs_evaluate(reviews, result$parameters)

cat("Default log_loss:", default_metrics$log_loss, "\n")
cat("Custom log_loss:", custom_metrics$log_loss, "\n")
```

## API Reference

### Scheduler (R6 Class)

```r
scheduler <- Scheduler$new(
  parameters = NULL,        # Custom params or NULL for defaults
  desired_retention = 0.9,  # Target recall probability
  maximum_interval = 36500, # Max days between reviews
  enable_fuzzing = FALSE    # Add randomness to intervals
)

scheduler$review_card(card, rating)     # Review and update card
scheduler$preview_card(card)            # Preview all 4 outcomes
scheduler$get_card_retrievability(card) # Current recall probability
```

### Card (R6 Class)

```r
card <- Card$new()
card$stability       # Days until 90% recall
card$difficulty      # Learning difficulty (1-10)
card$state           # New/Learning/Review/Relearning
card$get_retrievability()
card$clone_card()
```

### Optimizer Functions

| Function | Description |
|----------|-------------|
| `fsrs_optimize(reviews)` | Train custom parameters from review history |
| `fsrs_evaluate(reviews, params)` | Evaluate parameter accuracy |
| `fsrs_anki_to_reviews(revlog)` | Convert Anki revlog to required format |

### Low-Level Functions

Two parallel APIs are exported: validated R wrappers (recommended) and
thin direct-to-Rust wrappers.

**R wrappers (with argument checks):**

| Function | Description |
|----------|-------------|
| `fsrs_parameters()` | Get 21 default FSRS-6 parameters |
| `fsrs_new_card_state(rating, params)` | Initial state for a new card |
| `fsrs_next_memory_state(S, D, elapsed, rating, retention, params)` | State after a review |
| `fsrs_interval(S, retention, params)` | Optimal next-review interval |
| `fsrs_recall_probability(S, elapsed)` | Recall probability (scalar) |
| `fsrs_recall_probability_vec(S, elapsed)` | Recall probability (vectorized) |
| `fsrs_migrate_sm2(ease, interval, retention, params)` | Convert an SM-2 card to FSRS |
| `fsrs_simulate(ratings, params, retention)` | Step through a rating sequence |
| `fsrs_version()` | Algorithm version string |

**Direct Rust bindings (unchecked):**

| Function | Description |
|----------|-------------|
| `fsrs_default_parameters()` | Alias of `fsrs_parameters()` |
| `fsrs_initial_state(rating, params)` | Raw initial state |
| `fsrs_next_state(S, D, elapsed, rating, retention, params)` | Raw next state |
| `fsrs_next_interval(S, retention, params)` | Raw next interval |
| `fsrs_retrievability(S, elapsed)` | Raw retrievability |
| `fsrs_retrievability_vec(S, elapsed)` | Raw vectorized retrievability |
| `fsrs_from_sm2(ease, interval, retention, params)` | Raw SM-2 migration |
| `fsrs_memory_state(ratings, delta_ts, S0, D0, params)` | State from a rating history |

## Understanding FSRS

FSRS models memory with three variables:

- **Stability (S)**: Days until recall probability drops to 90%
- **Difficulty (D)**: How hard the material is (1-10)
- **Retrievability (R)**: Current probability of recall

Forgetting curve (as implemented in `fsrs-rs`):

```
factor = 0.9^(1/-decay) - 1
R(t)   = (1 + factor · t/S)^(-decay)
```

`decay` is the 21st parameter. With FSRS-6 defaults (`decay = 0.1542`)
`factor ≈ 0.9804`; with FSRS-5 defaults (`decay = 0.5`) `factor ≈ 0.2346`.
Either way `R(S) = 0.9`, i.e. stability is the interval at which recall
falls to 90%.

## Resources

- [FSRS Algorithm Wiki](https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm)
- [ABC of FSRS](https://github.com/open-spaced-repetition/fsrs4anki/wiki/ABC-of-FSRS)
- [fsrs-rs (Rust implementation)](https://github.com/open-spaced-repetition/fsrs-rs)

## License

MIT © 2026 [Christos Longros](https://github.com/chrislongros)

Based on [fsrs-rs](https://github.com/open-spaced-repetition/fsrs-rs) by the Open Spaced Repetition project.
