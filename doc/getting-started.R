## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----setup--------------------------------------------------------------------
library(rfsrs)

## ----forgetting-curve---------------------------------------------------------
# Visualize the forgetting curve for different stability values
stability_values <- c(1, 5, 10, 30)
days <- 0:60

# Simple base R plot
plot(NULL, xlim = c(0, 60), ylim = c(0, 1),
     xlab = "Days since last review", ylab = "Retrievability",
     main = "Forgetting Curves for Different Stability Values")
colors <- c("red", "orange", "blue", "green")
for (i in seq_along(stability_values)) {
  s <- stability_values[i]
  r <- sapply(days, function(d) fsrs_retrievability(s, d))
  lines(days, r, col = colors[i], lwd = 2)
}
legend("topright", legend = paste("S =", stability_values, "days"), 
       col = colors, lwd = 2)
abline(h = 0.9, lty = 2, col = "gray")

## ----initial-state------------------------------------------------------------
# Rating scale: 1=Again, 2=Hard, 3=Good, 4=Easy
state <- fsrs_initial_state(rating = 3)  # First review, rated "Good"
print(state)

## ----compare-initial----------------------------------------------------------
ratings <- 1:4
rating_names <- c("Again", "Hard", "Good", "Easy")

for (i in ratings) {
  s <- fsrs_initial_state(rating = i)
  cat(sprintf("%s (rating=%d): stability=%.2f, difficulty=%.2f\n",
              rating_names[i], i, s$stability, s$difficulty))
}

## ----check-retrievability-----------------------------------------------------
state <- fsrs_initial_state(rating = 3)

cat("Retrievability after:\n")
for (days in c(1, 3, 7, 14, 30)) {
  r <- fsrs_retrievability(state$stability, elapsed_days = days)
  cat(sprintf("  %2d days: %.1f%%\n", days, r * 100))
}

## ----next-interval------------------------------------------------------------
state <- fsrs_initial_state(rating = 3)

# Get interval for 90% desired retention (default)
interval_90 <- fsrs_next_interval(state$stability, desired_retention = 0.9)
cat(sprintf("Interval for 90%% retention: %.1f days\n", interval_90))

# Get interval for 85% desired retention (fewer reviews)
interval_85 <- fsrs_next_interval(state$stability, desired_retention = 0.85)
cat(sprintf("Interval for 85%% retention: %.1f days\n", interval_85))

# Get interval for 95% desired retention (more reviews)
interval_95 <- fsrs_next_interval(state$stability, desired_retention = 0.95)
cat(sprintf("Interval for 95%% retention: %.1f days\n", interval_95))

## ----next-state---------------------------------------------------------------
# Initial state
state <- fsrs_initial_state(rating = 3)
cat(sprintf("Initial: stability=%.2f\n", state$stability))

# Review after 2 days, rate "Good"
state <- fsrs_next_state(
  stability = state$stability,
  difficulty = state$difficulty,
  rating = 3,
  elapsed_days = 2
)
cat(sprintf("After review 1: stability=%.2f\n", state$stability))

# Review after 5 days, rate "Good"
state <- fsrs_next_state(
  stability = state$stability,
  difficulty = state$difficulty,
  rating = 3,
  elapsed_days = 5
)
cat(sprintf("After review 2: stability=%.2f\n", state$stability))

## ----simulate-learning--------------------------------------------------------
simulate_learning <- function(n_reviews = 10, rating = 3, desired_retention = 0.9) {
  state <- fsrs_initial_state(rating = rating)
  
  results <- data.frame(
    review = 0,
    day = 0,
    stability = state$stability,
    difficulty = state$difficulty,
    interval = NA
  )
  
  current_day <- 0
  
  for (i in 1:n_reviews) {
    interval <- fsrs_next_interval(state$stability, desired_retention)
    current_day <- current_day + interval
    state <- fsrs_next_state(state$stability, state$difficulty, interval, rating)
    
    results <- rbind(results, data.frame(
      review = i,
      day = current_day,
      stability = state$stability,
      difficulty = state$difficulty,
      interval = interval
    ))
  }
  
  return(results)
}

# Simulate 10 reviews, always rating "Good"
learning <- simulate_learning(n_reviews = 10, rating = 3)
print(learning)

## ----plot-learning------------------------------------------------------------
# Plot stability growth
plot(learning$review, learning$stability, type = "b", pch = 19,
     xlab = "Review Number", ylab = "Stability (days)",
     main = "Stability Growth Over Reviews")
grid()

## ----parameters---------------------------------------------------------------
params <- fsrs_default_parameters()
cat("FSRS-6 default parameters (", length(params), " values):\n", sep = "")
print(round(params, 4))

