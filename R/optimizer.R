# FSRS Parameter Optimizer

#' @export
fsrs_optimize <- function(reviews, enable_short_term = TRUE, verbose = TRUE) {
  if (!is.data.frame(reviews)) stop("reviews must be a data.frame")
  
  required_cols <- c("card_id", "rating", "delta_t")
  missing_cols <- setdiff(required_cols, names(reviews))
  if (length(missing_cols) > 0) {
    stop("reviews must have columns: ", paste(missing_cols, collapse = ", "))
  }
  
  if (nrow(reviews) < 10) stop("Need at least 10 reviews for optimization")
  if (any(reviews$rating < 1 | reviews$rating > 4, na.rm = TRUE)) {
    stop("All ratings must be between 1 and 4")
  }
  if (any(reviews$delta_t < 0, na.rm = TRUE)) {
    stop("delta_t values must be non-negative")
  }
  
  reviews <- reviews[order(reviews$card_id), ]
  
  card_ids <- reviews$card_id
  card_changes <- c(TRUE, card_ids[-1] != card_ids[-length(card_ids)])
  card_starts <- which(card_changes)
  
  n_cards <- length(card_starts)
  n_reviews <- nrow(reviews)
  
  if (verbose) {
    message(sprintf("Optimizing FSRS parameters..."))
    message(sprintf("  Cards: %d", n_cards))
    message(sprintf("  Reviews: %d", n_reviews))
  }
  
  result <- fsrs_optimize_raw(
    ratings = as.integer(reviews$rating),
    delta_ts = as.integer(reviews$delta_t),
    card_starts = as.integer(card_starts),
    enable_short_term = enable_short_term
  )
  
  result$n_cards <- n_cards
  result$n_reviews <- n_reviews
  
  if (verbose) {
    if (result$success) message("Optimization complete!")
    else message(sprintf("Optimization failed: %s", result$error))
  }
  
  result
}

#' @export
fsrs_evaluate <- function(reviews, params = NULL) {
  if (!is.data.frame(reviews)) stop("reviews must be a data.frame")
  
  required_cols <- c("card_id", "rating", "delta_t")
  missing_cols <- setdiff(required_cols, names(reviews))
  if (length(missing_cols) > 0) {
    stop("reviews must have columns: ", paste(missing_cols, collapse = ", "))
  }
  
  if (is.null(params)) params <- fsrs_default_parameters()
  if (length(params) != 21) stop("params must have exactly 21 values")
  
  reviews <- reviews[order(reviews$card_id), ]
  
  card_ids <- reviews$card_id
  card_changes <- c(TRUE, card_ids[-1] != card_ids[-length(card_ids)])
  card_starts <- which(card_changes)
  
  fsrs_evaluate_raw(
    ratings = as.integer(reviews$rating),
    delta_ts = as.integer(reviews$delta_t),
    card_starts = as.integer(card_starts),
    params = as.numeric(params)
  )
}

#' @export
fsrs_anki_to_reviews <- function(revlog, min_reviews = 2) {
  if (!is.data.frame(revlog)) stop("revlog must be a data.frame")
  
  card_col <- if ("cid" %in% names(revlog)) "cid" else if ("card_id" %in% names(revlog)) "card_id" else stop("revlog must have 'cid' or 'card_id' column")
  rating_col <- if ("ease" %in% names(revlog)) "ease" else if ("rating" %in% names(revlog)) "rating" else stop("revlog must have 'ease' or 'rating' column")
  time_col <- if ("id" %in% names(revlog)) "id" else if ("time" %in% names(revlog)) "time" else stop("revlog must have 'id' or 'time' column")
  
  df <- data.frame(
    card_id = revlog[[card_col]],
    rating = revlog[[rating_col]],
    time_ms = revlog[[time_col]]
  )
  
  df <- df[df$rating >= 1 & df$rating <= 4, ]
  df <- df[order(df$card_id, df$time_ms), ]
  
  df$delta_t <- ave(df$time_ms, df$card_id, FUN = function(x) {
    c(0, diff(x) / (1000 * 60 * 60 * 24))
  })
  df$delta_t <- round(df$delta_t)
  df$delta_t[df$delta_t < 0] <- 0
  
  card_counts <- table(df$card_id)
  valid_cards <- names(card_counts)[card_counts >= min_reviews]
  df <- df[df$card_id %in% valid_cards, ]
  
  data.frame(
    card_id = df$card_id,
    rating = df$rating,
    delta_t = as.integer(df$delta_t)
  )
}
