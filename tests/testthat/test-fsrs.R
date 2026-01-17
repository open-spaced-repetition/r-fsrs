# Test default parameters
test_that("fsrs_default_parameters returns 21 parameters", {
  params <- fsrs_default_parameters()
  expect_length(params, 21)
  expect_type(params, "double")
  expect_true(all(params >= 0))
})

# Test initial state
test_that("fsrs_initial_state returns valid state", {
  # Test all ratings
  for (rating in 1:4) {
    state <- fsrs_initial_state(rating = rating)
    expect_type(state, "list")
    expect_named(state, c("stability", "difficulty"))
    expect_true(state$stability > 0)
    expect_true(state$difficulty >= 1 && state$difficulty <= 10)
  }
})

test_that("fsrs_initial_state stability increases with rating", {
  state_again <- fsrs_initial_state(rating = 1)
  state_hard <- fsrs_initial_state(rating = 2)
  state_good <- fsrs_initial_state(rating = 3)
  state_easy <- fsrs_initial_state(rating = 4)
  
  expect_lt(state_again$stability, state_hard$stability)
  expect_lt(state_hard$stability, state_good$stability)
  expect_lt(state_good$stability, state_easy$stability)
})

# Test retrievability
test_that("fsrs_retrievability returns valid probability", {
  stability <- 2.5
  
  # Retrievability should be between 0 and 1
  r <- fsrs_retrievability(stability, elapsed_days = 1)
  expect_gte(r, 0)
  expect_lte(r, 1)
  
  # Retrievability should decrease over time
  r1 <- fsrs_retrievability(stability, elapsed_days = 1)
  r7 <- fsrs_retrievability(stability, elapsed_days = 7)
  r30 <- fsrs_retrievability(stability, elapsed_days = 30)
  
  expect_gt(r1, r7)
  expect_gt(r7, r30)
})

test_that("fsrs_retrievability at day 0 is ~1", {
  stability <- 5.0
  r <- fsrs_retrievability(stability, elapsed_days = 0)
  expect_equal(r, 1, tolerance = 0.001)
})

test_that("fsrs_retrievability at stability days is ~0.9", {
  stability <- 10.0
  # By definition, stability is time until R drops to 90%
  r <- fsrs_retrievability(stability, elapsed_days = stability)
  expect_equal(r, 0.9, tolerance = 0.01)
})

# Test next state
test_that("fsrs_next_state returns valid state", {
  initial <- fsrs_initial_state(rating = 3)
  
  new_state <- fsrs_next_state(
    stability = initial$stability,
    difficulty = initial$difficulty,
    rating = 3,
    elapsed_days = 1
  )
  
  expect_type(new_state, "list")
  expect_named(new_state, c("stability", "difficulty"))
  expect_true(new_state$stability > 0)
  expect_true(new_state$difficulty >= 1 && new_state$difficulty <= 10)
})

test_that("fsrs_next_state stability increases on successful review", {
  initial <- fsrs_initial_state(rating = 3)
  
  # Review at optimal time with "Good" rating
  new_state <- fsrs_next_state(
    stability = initial$stability,
    difficulty = initial$difficulty,
    rating = 3,
    elapsed_days = initial$stability
  )
  
  expect_gt(new_state$stability, initial$stability)
})

test_that("fsrs_next_state stability decreases on 'Again'", {
  # Build up some stability first
  state <- fsrs_initial_state(rating = 3)
  state <- fsrs_next_state(state$stability, state$difficulty, 3, 2)
  state <- fsrs_next_state(state$stability, state$difficulty, 3, 5)
  
  high_stability <- state$stability
  
  # Now fail the card
  failed_state <- fsrs_next_state(
    stability = state$stability,
    difficulty = state$difficulty,
    rating = 1,  # Again
    elapsed_days = 10
  )
  
  expect_lt(failed_state$stability, high_stability)
})

# Test next interval
test_that("fsrs_next_interval returns positive value", {
  state <- fsrs_initial_state(rating = 3)
  
  # Default retention of 0.9
  interval <- fsrs_next_interval(state$stability, desired_retention = 0.9)
  
  expect_type(interval, "double")
  expect_gte(interval, 0)
})

test_that("fsrs_next_interval increases with stability", {
  state1 <- fsrs_initial_state(rating = 3)
  state2 <- fsrs_next_state(state1$stability, state1$difficulty, 3, 2)
  state3 <- fsrs_next_state(state2$stability, state2$difficulty, 3, 5)
  
  int1 <- fsrs_next_interval(state1$stability, 0.9)
  int2 <- fsrs_next_interval(state2$stability, 0.9)
  int3 <- fsrs_next_interval(state3$stability, 0.9)
  
  expect_lt(int1, int2)
  expect_lt(int2, int3)
})

test_that("fsrs_next_interval decreases with higher retention", {
  state <- fsrs_initial_state(rating = 3)
  
  int_85 <- fsrs_next_interval(state$stability, desired_retention = 0.85)
  int_90 <- fsrs_next_interval(state$stability, desired_retention = 0.90)
  int_95 <- fsrs_next_interval(state$stability, desired_retention = 0.95)
  
  # Higher desired retention = shorter intervals
  expect_gt(int_85, int_90)
  expect_gt(int_90, int_95)
})

# Integration test
test_that("full review cycle works correctly", {
  # Simulate learning a card over multiple reviews
  state <- fsrs_initial_state(rating = 3)
  
  # Track stability growth
  stabilities <- c(state$stability)
  
  for (i in 1:5) {
    interval <- fsrs_next_interval(state$stability, desired_retention = 0.9)
    state <- fsrs_next_state(state$stability, state$difficulty, rating = 3, elapsed_days = interval)
    stabilities <- c(stabilities, state$stability)
  }
  
  # Stability should monotonically increase with successful reviews
  for (i in 2:length(stabilities)) {
    expect_gt(stabilities[i], stabilities[i-1])
  }
})
