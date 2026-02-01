# rfsrs

<!-- badges: start -->
[![R-CMD-check](https://github.com/open-spaced-repetition/r-fsrs/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/open-spaced-repetition/r-fsrs/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

R bindings for [fsrs-rs](https://github.com/open-spaced-repetition/fsrs-rs), the Rust implementation of the Free Spaced Repetition Scheduler (FSRS) algorithm.

FSRS is a modern spaced repetition algorithm based on the DSR (Difficulty, Stability, Retrievability) model of memory. It uses 21 optimizable parameters to predict optimal review intervals more accurately than traditional algorithms like SM-2.

## Installation

```r
# Install Rust first: https://rustup.rs

# From GitHub
remotes::install_github("open-spaced-repetition/r-fsrs")

# From r-universe
install.packages("rfsrs", repos = "https://open-spaced-repetition.r-universe.dev")
```

## Quick Start

### Using the Scheduler (Recommended)

```r
library(rfsrs)

# Create a scheduler with default parameters
scheduler <- Scheduler$new(desired_retention = 0.9)

# Create a new card
card <- Card$new()

# Review the card with rating Good (3)
result <- scheduler$review_card(card, Rating$Good)
print(card)
# FSRS Card
#   State: Review 
#   Due: 2024-01-05 10:30:00 
#   Stability: 3.17 days
#   Difficulty: 5.31 

# Preview all four outcomes without modifying the card
outcomes <- scheduler$preview_card(card)
outcomes$again$interval
outcomes$good$interval
outcomes$easy$interval
```

### Using Low-Level Functions

```r
library(rfsrs)

# Get default parameters (21 values)
params <- fsrs_default_parameters()

# Create initial state for a new card rated "Good"
state <- fsrs_initial_state(rating = 3)
# $stability: 3.17
# $difficulty: 5.31

# Calculate next state after reviewing
new_state <- fsrs_next_state(
  stability = state$stability,
  difficulty = state$difficulty,
  elapsed_days = 3,
  rating = 3  # Good
)

# Get optimal interval for 90% retention
interval <- fsrs_next_interval(new_state$stability, desired_retention = 0.9)

# Check recall probability after 5 days
prob <- fsrs_retrievability(new_state$stability, elapsed_days = 5)
```

### Get All Rating Outcomes at Once

```r
# Returns outcomes for all 4 ratings in one call
outcomes <- fsrs_repeat(
  stability = 5.0,
  difficulty = 5.0,
  elapsed_days = 3,
  desired_retention = 0.9
)

outcomes$again$interval  # Days until next review if rated Again
outcomes$hard$interval   # Days until next review if rated Hard
outcomes$good$interval   # Days until next review if rated Good
outcomes$easy$interval   # Days until next review if rated Easy
```

### Using Custom Parameters

```r
# Train your own parameters with fsrs-optimizer, then use them:
my_params <- c(0.4, 0.6, 2.4, 5.8, 4.93, 0.94, 0.86, 0.01, 
               1.49, 0.14, 0.94, 2.18, 0.05, 0.34, 1.26, 
               0.29, 2.61, 0.0, 0.0, 0.0, 0.0)

# With Scheduler
scheduler <- Scheduler$new(parameters = my_params, desired_retention = 0.9)

# Or with low-level functions
state <- fsrs_initial_state(rating = 3, params = my_params)
```

### Migrating from SM-2 (Anki Default)

```r
# Convert existing SM-2 ease/interval to FSRS state
state <- fsrs_from_sm2(
  ease_factor = 2.5,   # Anki ease factor

  interval = 10,       # Current interval in days
  sm2_retention = 0.9  # Assumed retention rate
)

# Now use this state with FSRS
new_state <- fsrs_next_state(state$stability, state$difficulty, 
                             elapsed_days = 10, rating = 3)
```

### Computing State from Review History

```r
# Replay a sequence of reviews to get current state
state <- fsrs_memory_state(
  ratings = c(3, 3, 2, 3, 4),      # Good, Good, Hard, Good, Easy
  delta_ts = c(0, 1, 3, 7, 14)     # Days between reviews
)
```

### Vectorized Operations (for large datasets)
```r
# Efficiently calculate retrievability for many cards
stabilities <- c(5, 10, 15, 20)
elapsed <- c(3, 5, 7, 10)
probs <- fsrs_retrievability_vec(stabilities, elapsed)
```

## API Reference

### R6 Classes

| Class | Description |
|-------|-------------|
| `Card` | Represents a flashcard with memory state |
| `Scheduler` | Schedules reviews using FSRS algorithm |
| `ReviewLog` | Records a single review event |

### Rating and State Constants

```r
Rating$Again  # 1 - Complete blackout
Rating$Hard   # 2 - Significant difficulty
Rating$Good   # 3 - Correct with some hesitation
Rating$Easy   # 4 - Perfect response

State$New        # 0 - Never reviewed
State$Learning   # 1 - Initial learning phase
State$Review     # 2 - Graduated to review
State$Relearning # 3 - Lapsed, relearning
```

### Low-Level Functions

| Function | Description |
|----------|-------------|
| `fsrs_default_parameters()` | Get 21 default FSRS-6 parameters |
| `fsrs_initial_state(rating, params)` | Initial state for new card |
| `fsrs_next_state(S, D, elapsed, rating, params)` | Next state after review |
| `fsrs_next_interval(S, retention, params)` | Optimal interval for target retention |
| `fsrs_retrievability(S, elapsed)` | Recall probability |
| `fsrs_retrievability_vec(S, elapsed)` | Vectorized retrievability |
| `fsrs_repeat(S, D, elapsed, retention, params)` | All 4 outcomes at once |
| `fsrs_from_sm2(ease, interval, retention, params)` | Convert SM-2 to FSRS |
| `fsrs_memory_state(ratings, delta_ts, ...)` | State from review history |

## Understanding FSRS

FSRS models memory with three variables:

- **Stability (S)**: Time in days for recall probability to drop to 90%. Higher = slower forgetting.
- **Difficulty (D)**: How hard the material is (1-10). Higher = slower stability growth.
- **Retrievability (R)**: Current probability of recall (0-1). Decays over time.

The forgetting curve formula:
```
R(t) = (1 + t/(9·S))^(-0.5)
```

Where `t` is days since last review and `S` is stability.

## Resources

- [FSRS Algorithm Wiki](https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm)
- [ABC of FSRS](https://github.com/open-spaced-repetition/fsrs4anki/wiki/ABC-of-FSRS)
- [fsrs-rs (Rust implementation)](https://github.com/open-spaced-repetition/fsrs-rs)
- [py-fsrs (Python implementation)](https://github.com/open-spaced-repetition/py-fsrs)

## License

MIT
