#' Optimize FSRS Parameters
#'
#' Trains custom FSRS parameters from review history using machine learning.
#' This typically improves prediction accuracy by 10-30% compared to defaults.
#'
#' @param reviews A data.frame with columns:
#'   \describe{
#'     \item{card_id}{Unique identifier for each card}
#'     \item{rating}{Review rating (1=Again, 2=Hard, 3=Good, 4=Easy)}
#'     \item{delta_t}{Days since previous review (0 for first review)}
#'   }
#' @param enable_short_term Whether to enable short-term memory modeling (default TRUE).
#' @param verbose Print progress messages (default TRUE).
#' @return List with:
#'   \describe{
#'     \item{success}{Logical indicating if optimization succeeded}
#'     \item{parameters}{Numeric vector of 21 optimized parameters}
#'     \item{error}{Error message if failed, NULL otherwise}
#'     \item{n_cards}{Number of cards used}
#'     \item{n_reviews}{Number of reviews used}
#'   }
#' @export
#' @examples
#' \dontrun{
#' reviews <- data.frame(
#'   card_id = c(1, 1, 1, 2, 2, 2),
#'   rating = c(3, 3, 4, 2, 3, 3),
#'   delta_t = c(0, 1, 3, 0, 1, 5)
#' )
#' result <- fsrs_optimize(reviews)
#' if (result$success) {
#'   print(result$parameters)
#' }
#' }
fsrs_optimize <- function(reviews, enable_short_term = TRUE, verbose = TRUE) {
  if (!is.data.frame(reviews)) stop("reviews must be a data.frame")
  required_cols <- c("card_id", "rating", "delta_t")
  missing_cols <- setdiff(required_cols, names(reviews))
  if (length(missing_cols) > 0) {
    stop("reviews must have columns: ", paste(missing_cols, collapse = ", "))
  }
  card_review_counts <- table(reviews$card_id)
  valid_cards_check <- sum(card_review_counts >= 2)
  if (valid_cards_check < 5) stop("Need at least 5 cards with 2+ reviews for optimization")
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

#' Evaluate FSRS Parameters
#'
#' Evaluates how well FSRS parameters predict actual recall outcomes.
#'
#' @param reviews A data.frame with columns: card_id, rating, delta_t
#'   (same format as \code{\link{fsrs_optimize}}).
#' @param params Optional vector of 21 FSRS parameters. Uses defaults if NULL.
#' @return List with:
#'   \describe{
#'     \item{log_loss}{Log loss metric (may be NaN for some data)}
#'     \item{rmse_bins}{Root mean square error of binned predictions (lower is better)}
#'     \item{success}{Logical indicating if evaluation succeeded}
#'   }
#' @export
#' @examples
#' \dontrun{
#' # Compare default vs custom parameters
#' default_metrics <- fsrs_evaluate(reviews, NULL)
#' custom_metrics <- fsrs_evaluate(reviews, my_params)
#' cat("Default RMSE:", default_metrics$rmse_bins, "\n")
#' cat("Custom RMSE:", custom_metrics$rmse_bins, "\n")
#' }
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

#' Convert Anki Review Log to FSRS Format
#'
#' Converts an Anki review log (from ankiR or similar) to the format
#' required by \code{\link{fsrs_optimize}}.
#'
#' @param revlog A data.frame with Anki review data. Supports column names from
#'   ankiR (\code{cid}, \code{ease}, \code{id}) or standard names
#'   (\code{card_id}, \code{rating}, \code{time}).
#' @param min_reviews Minimum number of reviews required per card (default 2).
#' @return A data.frame with columns: card_id, rating, delta_t
#' @export
#' @examples
#' \dontrun{
#' library(ankiR)
#' revlog <- anki_revlog()
#' reviews <- fsrs_anki_to_reviews(revlog, min_reviews = 3)
#' result <- fsrs_optimize(reviews)
#' }
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
  df$delta_t <- stats::ave(df$time_ms, df$card_id, FUN = function(x) {
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
