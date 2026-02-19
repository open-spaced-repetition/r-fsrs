
test_that("Card initializes with correct defaults", {
  card <- Card$new()
  expect_equal(card$state, State$New)
  expect_equal(card$stability, 0)
  expect_equal(card$difficulty, 0)
  expect_equal(card$reps, 0L)
  expect_equal(card$lapses, 0L)
  expect_null(card$last_review)
})

test_that("Card$get_retrievability returns 1.0 for new card", {
  card <- Card$new()
  expect_equal(card$get_retrievability(), 1.0)
})

test_that("Card$deep_clone produces independent copy", {
  card <- Card$new()
  card2 <- card$deep_clone()
  card2$reps <- 99L
  expect_equal(card$reps, 0L)  # original unchanged
})

test_that("Scheduler initializes with defaults", {
  s <- Scheduler$new()
  expect_equal(s$desired_retention, 0.9)
  expect_equal(s$maximum_interval, 36500L)
  expect_false(s$enable_fuzzing)
  expect_length(s$parameters, 21)
})

test_that("Scheduler rejects invalid parameters length", {
  expect_error(Scheduler$new(parameters = 1:10), "length")
})

test_that("New card transitions to Learning on Good rating", {
  s <- Scheduler$new()
  card <- Card$new()
  result <- s$review_card(card, Rating$Good)
  expect_equal(card$state, State$Learning)
})

test_that("New card transitions to Learning on Again rating", {
  s <- Scheduler$new()
  card <- Card$new()
  result <- s$review_card(card, Rating$Again)
  expect_equal(card$state, State$Learning)
})

test_that("Learning card graduates to Review on Good", {
  s <- Scheduler$new()
  card <- Card$new()
  s$review_card(card, Rating$Good)               # New -> Learning
  expect_equal(card$state, State$Learning)
  s$review_card(card, Rating$Good)               # Learning -> Review
  expect_equal(card$state, State$Review)
})

test_that("Learning card stays Learning on Hard", {
  s <- Scheduler$new()
  card <- Card$new()
  s$review_card(card, Rating$Good)               # New -> Learning
  s$review_card(card, Rating$Hard)               # should stay Learning
  expect_equal(card$state, State$Learning)
})

test_that("Review card goes to Relearning on Again", {
  s <- Scheduler$new()
  card <- Card$new()
  s$review_card(card, Rating$Good)               # New -> Learning
  s$review_card(card, Rating$Good)               # Learning -> Review
  s$review_card(card, Rating$Again)              # Review -> Relearning
  expect_equal(card$state, State$Relearning)
  expect_equal(card$lapses, 1L)
})

test_that("review_card increments reps", {
  s <- Scheduler$new()
  card <- Card$new()
  s$review_card(card, Rating$Good)
  expect_equal(card$reps, 1L)
  s$review_card(card, Rating$Good)
  expect_equal(card$reps, 2L)
})

test_that("review_card sets last_review and due", {
  s <- Scheduler$new()
  card <- Card$new()
  now <- as.POSIXct("2025-01-01 12:00:00", tz = "UTC")
  s$review_card(card, Rating$Good, review_datetime = now)
  expect_equal(card$last_review, now)
  expect_true(card$due > now)
})

test_that("fsrs_simulate clock advances between reviews", {
  sim <- fsrs_simulate(c(3, 3, 4, 3))
  # Intervals should generally increase as stability grows
  expect_true(all(sim$interval >= 1))
  # All states should be valid
  expect_true(all(sim$stability > 0))
  expect_true(all(sim$difficulty >= 1 & sim$difficulty <= 10))
})

test_that("ReviewLog captures correct state", {
  s <- Scheduler$new()
  card <- Card$new()
  result <- s$review_card(card, Rating$Good)
  log <- result$review_log
  expect_equal(log$state, State$New)        # state BEFORE review
  expect_equal(log$rating, Rating$Good)
})

test_that("preview_card returns all four outcomes", {
  s <- Scheduler$new()
  card <- Card$new()
  outcomes <- s$preview_card(card)
  expect_named(outcomes, c("again", "hard", "good", "easy"))
  for (nm in c("again", "hard", "good", "easy")) {
    expect_true(outcomes[[nm]]$stability > 0)
    expect_true(outcomes[[nm]]$interval >= 1)
  }
})

test_that("fsrs_version returns FSRS-5", {
  expect_equal(fsrs_version(), "FSRS-5")
})

test_that("fsrs_new_card_state validates rating", {
  expect_error(fsrs_new_card_state(5),  "rating")
  expect_error(fsrs_new_card_state(0),  "rating")
  expect_error(fsrs_new_card_state(-1), "rating")
})

test_that("fsrs_recall_probability validates inputs", {
  expect_error(fsrs_recall_probability(-1, 5),  "stability")
  expect_error(fsrs_recall_probability(5, -1),  "elapsed_days")
})

test_that("fsrs_interval validates desired_retention", {
  expect_error(fsrs_interval(5, 0),   "desired_retention")
  expect_error(fsrs_interval(5, 1),   "desired_retention")
  expect_error(fsrs_interval(5, 1.5), "desired_retention")
  expect_error(fsrs_interval(-1),     "stability")
})

test_that("Card serialization round-trips correctly", {
  s <- Scheduler$new()
  card <- Card$new()
  s$review_card(card, Rating$Good)
  json <- card$to_json()
  card2 <- Card_from_json(json)
  expect_equal(card$stability,  card2$stability,  tolerance = 1e-4)
  expect_equal(card$difficulty, card2$difficulty, tolerance = 1e-3)
  expect_equal(card$state,      card2$state)
  expect_equal(card$reps,       card2$reps)
})
