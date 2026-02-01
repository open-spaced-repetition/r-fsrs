# ============================================================================
# IMPROVED fsrs_api.R
# Key changes:
# 1. Scheduler actually uses custom parameters
# 2. Better state transitions
# 3. Added preview_card() method
# ============================================================================

#' @title FSRS Rating
#' @description Rating values for card reviews
#' @export
Rating <- list(
  Again = 1L,
  Hard = 2L,
  Good = 3L,
  Easy = 4L
)

#' @title FSRS State
#' @description Card states in the FSRS system
#' @export
State <- list(
  New = 0L,
  Learning = 1L,
  Review = 2L,
  Relearning = 3L
)

#' @title FSRS Card
#' @description R6 class representing a flashcard
#' @export
Card <- R6::R6Class(
  "Card",
  public = list(
    due = NULL,
    stability = NULL,
    difficulty = NULL,
    elapsed_days = NULL,
    scheduled_days = NULL,
    reps = NULL,
    lapses = NULL,
    state = NULL,
    last_review = NULL,
    
    #' @description Create a new Card
    #' @param due Initial due date (default: now)
    initialize = function(due = Sys.time()) {
      self$due <- due
      self$stability <- 0
      self$difficulty <- 0
      self$elapsed_days <- 0
      self$scheduled_days <- 0
      self$reps <- 0L
      self$lapses <- 0L
      self$state <- State$New
      self$last_review <- NULL
    },
    
    #' @description Get current retrievability
    #' @param now Reference time (default: Sys.time())
    get_retrievability = function(now = Sys.time()) {
      if (self$state == State$New || is.null(self$stability) || self$stability == 0) {
        return(1.0)
      }
      elapsed <- as.numeric(difftime(now, self$last_review, units = "days"))
      fsrs_retrievability(self$stability, max(0, elapsed))
    },
    
    #' @description Serialize card to JSON
    to_json = function() {
      jsonlite::toJSON(list(
        due = format(self$due, "%Y-%m-%dT%H:%M:%S%z"),
        stability = self$stability,
        difficulty = self$difficulty,
        elapsed_days = self$elapsed_days,
        scheduled_days = self$scheduled_days,
        reps = self$reps,
        lapses = self$lapses,
        state = self$state,
        last_review = if (!is.null(self$last_review)) {
          format(self$last_review, "%Y-%m-%dT%H:%M:%S%z")
        } else {
          NULL
        }
      ), auto_unbox = TRUE)
    },
    
    #' @description Clone the card
    clone_card = function() {
      new_card <- Card$new(self$due)
      new_card$stability <- self$stability
      new_card$difficulty <- self$difficulty
      new_card$elapsed_days <- self$elapsed_days
      new_card$scheduled_days <- self$scheduled_days
      new_card$reps <- self$reps
      new_card$lapses <- self$lapses
      new_card$state <- self$state
      new_card$last_review <- self$last_review
      new_card
    },
    
    #' @description Print card details
    print = function() {
      state_name <- names(State)[which(unlist(State) == self$state)]
      cat("FSRS Card\n")
      cat("  State:", state_name, "\n")
      cat("  Due:", format(self$due), "\n")
      cat("  Stability:", round(self$stability, 2), "days\n")
      cat("  Difficulty:", round(self$difficulty, 2), "\n")
      cat("  Reps:", self$reps, "\n")
      cat("  Lapses:", self$lapses, "\n")
      if (!is.null(self$last_review)) {
        cat("  Last review:", format(self$last_review), "\n")
        cat("  Retrievability:", sprintf("%.1f%%", self$get_retrievability() * 100), "\n")
      }
      invisible(self)
    }
  )
)

#' @title Create Card from JSON
#' @param json JSON string
#' @return Card object
#' @export
Card_from_json <- function(json) {
  data <- jsonlite::fromJSON(json)
  card <- Card$new()
  card$due <- as.POSIXct(data$due, format = "%Y-%m-%dT%H:%M:%S%z")
  card$stability <- data$stability
  card$difficulty <- data$difficulty
  card$elapsed_days <- data$elapsed_days
  card$scheduled_days <- data$scheduled_days
  card$reps <- as.integer(data$reps)
  card$lapses <- as.integer(data$lapses)
  card$state <- as.integer(data$state)
  if (!is.null(data$last_review)) {
    card$last_review <- as.POSIXct(data$last_review, format = "%Y-%m-%dT%H:%M:%S%z")
  }
  card
}

#' @title FSRS Review Log
#' @description R6 class representing a review log entry
#' @export
ReviewLog <- R6::R6Class(
  "ReviewLog",
  public = list(
    rating = NULL,
    scheduled_days = NULL,
    elapsed_days = NULL,
    review_datetime = NULL,
    state = NULL,
    
    initialize = function(rating, scheduled_days, elapsed_days, review_datetime, state) {
      self$rating <- rating
      self$scheduled_days <- scheduled_days
      self$elapsed_days <- elapsed_days
      self$review_datetime <- review_datetime
      self$state <- state
    },
    
    to_json = function() {
      jsonlite::toJSON(list(
        rating = self$rating,
        scheduled_days = self$scheduled_days,
        elapsed_days = self$elapsed_days,
        review_datetime = format(self$review_datetime, "%Y-%m-%dT%H:%M:%S%z"),
        state = self$state
      ), auto_unbox = TRUE)
    },
    
    print = function() {
      rating_name <- names(Rating)[which(unlist(Rating) == self$rating)]
      state_name <- names(State)[which(unlist(State) == self$state)]
      cat("FSRS ReviewLog\n")
      cat("  Rating:", rating_name, "\n")
      cat("  Previous state:", state_name, "\n")
      cat("  Review time:", format(self$review_datetime), "\n")
      cat("  Elapsed days:", round(self$elapsed_days, 1), "\n")
      cat("  Scheduled days:", self$scheduled_days, "\n")
      invisible(self)
    }
  )
)

#' @title FSRS Scheduler
#' @description R6 class for scheduling card reviews using FSRS algorithm
#' @export
Scheduler <- R6::R6Class(
  "Scheduler",
  public = list(
    parameters = NULL,
    desired_retention = NULL,
    maximum_interval = NULL,
    enable_fuzzing = NULL,
    
    #' @description Create a new Scheduler
    #' @param parameters Optional vector of 21 FSRS parameters. Uses defaults if NULL.
    #' @param desired_retention Target retention rate (default 0.9)
    #' @param maximum_interval Maximum interval in days (default 36500 = 100 years)
    #' @param enable_fuzzing Whether to add random fuzz to intervals (default FALSE)
    initialize = function(parameters = NULL, desired_retention = 0.9, 
                          maximum_interval = 36500L, enable_fuzzing = FALSE) {
      self$parameters <- if (is.null(parameters)) {
        fsrs_default_parameters()
      } else {
        stopifnot(length(parameters) == 21)
        as.numeric(parameters)
      }
      self$desired_retention <- desired_retention
      self$maximum_interval <- maximum_interval
      self$enable_fuzzing <- enable_fuzzing
    },
    
    #' @description Preview all four rating outcomes without modifying the card
    #' @param card Card object to preview
    #' @param review_datetime Time of review (default: now)
    #' @return List with $again, $hard, $good, $easy outcomes
    preview_card = function(card, review_datetime = Sys.time()) {
      elapsed_days <- private$calc_elapsed(card, review_datetime)
      
      stability <- if (card$state == State$New) NULL else card$stability
      difficulty <- if (card$state == State$New) NULL else card$difficulty
      
      outcomes <- fsrs_repeat(
        stability = stability,
        difficulty = difficulty,
        elapsed_days = elapsed_days,
        desired_retention = self$desired_retention,
        params = self$parameters
      )
      
      # Apply maximum interval and fuzzing to each outcome
      for (rating_name in c("again", "hard", "good", "easy")) {
        interval <- outcomes[[rating_name]]$interval
        interval <- min(interval, self$maximum_interval)
        if (self$enable_fuzzing && interval > 2) {
          fuzz_range <- max(1, round(interval * 0.05))
          interval <- interval + sample(-fuzz_range:fuzz_range, 1)
        }
        outcomes[[rating_name]]$interval <- round(max(1, interval))
      }
      
      outcomes
    },
    
    #' @description Review a card and update its state
    #' @param card Card object to review (modified in place)
    #' @param rating Rating: 1=Again, 2=Hard, 3=Good, 4=Easy (or use Rating$Good etc.)
    #' @param review_datetime Time of review (default: now)
    #' @return List with $card (updated) and $review_log
    review_card = function(card, rating, review_datetime = Sys.time()) {
      if (!rating %in% 1:4) {
        stop("Rating must be 1 (Again), 2 (Hard), 3 (Good), or 4 (Easy)")
      }
      
      elapsed_days <- private$calc_elapsed(card, review_datetime)
      previous_state <- card$state
      
      # Create review log BEFORE updating card
      review_log <- ReviewLog$new(
        rating = rating,
        scheduled_days = card$scheduled_days,
        elapsed_days = elapsed_days,
        review_datetime = review_datetime,
        state = previous_state
      )
      
      # Get new memory state
      if (card$state == State$New) {
        new_state <- fsrs_initial_state(rating, self$parameters)
      } else {
        new_state <- fsrs_next_state(
          card$stability, card$difficulty, elapsed_days, rating, 
          self$parameters
        )
      }
      
      card$stability <- new_state$stability
      card$difficulty <- new_state$difficulty
      
      # Update card state based on rating and previous state
      card$state <- private$next_card_state(previous_state, rating)
      
      # Track lapses
      if (rating == Rating$Again && previous_state %in% c(State$Review, State$Relearning)) {
        card$lapses <- card$lapses + 1L
      }
      
      # Calculate and apply interval
      interval <- fsrs_next_interval(card$stability, self$desired_retention, self$parameters)
      interval <- min(interval, self$maximum_interval)
      
      if (self$enable_fuzzing && interval > 2) {
        fuzz_range <- max(1, round(interval * 0.05))
        interval <- interval + sample(-fuzz_range:fuzz_range, 1)
      }
      
      card$scheduled_days <- round(max(1, interval))
      card$elapsed_days <- elapsed_days
      card$reps <- card$reps + 1L
      card$last_review <- review_datetime
      card$due <- review_datetime + as.difftime(card$scheduled_days, units = "days")
      
      list(card = card, review_log = review_log)
    },
    
    #' @description Get current retrievability of a card
    #' @param card Card object
    #' @param now Reference time (default: now)
    get_card_retrievability = function(card, now = Sys.time()) {
      card$get_retrievability(now)
    },
    
    #' @description Serialize scheduler to JSON
    to_json = function() {
      jsonlite::toJSON(list(
        parameters = self$parameters,
        desired_retention = self$desired_retention,
        maximum_interval = self$maximum_interval,
        enable_fuzzing = self$enable_fuzzing
      ), auto_unbox = TRUE)
    },
    
    #' @description Print scheduler details
    print = function() {
      cat("FSRS Scheduler\n")
      cat("  Desired retention:", sprintf("%.0f%%", self$desired_retention * 100), "\n")
      cat("  Maximum interval:", self$maximum_interval, "days\n")
      cat("  Fuzzing:", if (self$enable_fuzzing) "enabled" else "disabled", "\n")
      cat("  Parameters:", if (identical(self$parameters, fsrs_default_parameters())) {
        "default"
      } else {
        "custom"
      }, "\n")
      invisible(self)
    }
  ),
  
  private = list(
    calc_elapsed = function(card, review_datetime) {
      if (is.null(card$last_review) || card$state == State$New) {
        0
      } else {
        as.numeric(difftime(review_datetime, card$last_review, units = "days"))
      }
    },
    
    # State transition logic matching py-fsrs/rs-fsrs
    next_card_state = function(previous_state, rating) {
      if (rating == Rating$Again) {
        # Again always puts card in learning/relearning
        if (previous_state == State$New) {
          State$Learning
        } else {
          State$Relearning
        }
      } else {
        # Hard/Good/Easy graduate the card to Review
        State$Review
      }
    }
  )
)

#' @title Create Scheduler from JSON
#' @param json JSON string
#' @return Scheduler object
#' @export
Scheduler_from_json <- function(json) {
  data <- jsonlite::fromJSON(json)
  Scheduler$new(
    parameters = data$parameters,
    desired_retention = data$desired_retention,
    maximum_interval = data$maximum_interval,
    enable_fuzzing = data$enable_fuzzing
  )
}

# ============================================================================
# CONVENIENCE FUNCTIONS
# ============================================================================

#' @title Simulate Learning a Card
#' @description Simulate reviewing a card multiple times with given ratings
#' @param ratings Vector of ratings for each review
#' @param params Optional custom parameters
#' @param desired_retention Target retention (default 0.9)
#' @return data.frame with review history
#' @export
fsrs_simulate <- function(ratings, params = NULL, desired_retention = 0.9) {
  scheduler <- Scheduler$new(
    parameters = params,
    desired_retention = desired_retention
  )
  card <- Card$new()
  
  results <- vector("list", length(ratings))
  
  for (i in seq_along(ratings)) {
    result <- scheduler$review_card(card, ratings[i])
    results[[i]] <- data.frame(
      review = i,
      rating = ratings[i],
      stability = card$stability,
      difficulty = card$difficulty,
      interval = card$scheduled_days,
      state = card$state
    )
  }
  
  do.call(rbind, results)
}
