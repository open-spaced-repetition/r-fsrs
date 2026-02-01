test_that("fsrs_optimize validates input", {
  bad_df <- data.frame(x = 1:10)
  expect_error(fsrs_optimize(bad_df, verbose = FALSE), "must have columns")
  expect_error(fsrs_optimize(list(a = 1)), "must be a data.frame")
})

test_that("fsrs_evaluate validates input", {
  reviews <- data.frame(
    card_id = rep(1:5, each = 3),
    rating = rep(c(3, 3, 4), 5),
    delta_t = rep(c(0, 1, 3), 5)
  )
  expect_error(fsrs_evaluate(reviews, params = c(1, 2, 3)), "exactly 21 values")
})

test_that("fsrs_anki_to_reviews converts data correctly", {
  revlog <- data.frame(
    cid = c(1, 1, 1, 2, 2, 2, 3, 3),
    ease = c(3, 3, 4, 2, 3, 3, 3, 4),
    id = c(1000, 2000, 5000, 1000, 3000, 8000, 1000, 4000) * 60 * 60 * 24
  )
  
  result <- fsrs_anki_to_reviews(revlog, min_reviews = 2)
  
  expect_s3_class(result, "data.frame")
  expect_true(all(c("card_id", "rating", "delta_t") %in% names(result)))
  expect_true(all(result$rating >= 1 & result$rating <= 4))
  expect_true(all(result$delta_t >= 0))
})

test_that("fsrs_evaluate works with valid data", {
  reviews <- data.frame(
    card_id = rep(1:10, each = 4),
    rating = rep(c(3, 3, 2, 4), 10),
    delta_t = as.integer(rep(c(0, 1, 3, 7), 10))
  )
  
  result <- fsrs_evaluate(reviews)
  
  expect_type(result, "list")
  expect_true("log_loss" %in% names(result))
  expect_true("success" %in% names(result))
})

# Skip optimizer test on CRAN - it's slow
test_that("fsrs_optimize works with sufficient data", {
  skip_on_cran()
  
  # Generate realistic review data with proper intervals
  set.seed(42)
  n_cards <- 30
  
  # Each card has 4-6 reviews with increasing intervals
  reviews_list <- lapply(1:n_cards, function(card_id) {
    n_reviews <- sample(4:6, 1)
    data.frame(
      card_id = card_id,
      rating = sample(2:4, n_reviews, replace = TRUE, prob = c(0.2, 0.6, 0.2)),
      delta_t = as.integer(c(0, cumsum(sample(1:7, n_reviews - 1, replace = TRUE))))
    )
  })
  
  reviews <- do.call(rbind, reviews_list)
  
  result <- fsrs_optimize(reviews, verbose = FALSE)
  
  expect_type(result, "list")
  expect_true("parameters" %in% names(result))
  expect_true("success" %in% names(result))
})
