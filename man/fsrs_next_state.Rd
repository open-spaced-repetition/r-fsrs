\name{fsrs_next_state}
\alias{fsrs_next_state}
\title{Calculate Next Memory State}
\description{
Updates memory state after a review, calculating new stability and difficulty.
}
\usage{
fsrs_next_state(stability, difficulty, elapsed_days, rating, desired_retention, params)
}
\arguments{
\item{stability}{Current memory stability in days.}
\item{difficulty}{Current difficulty (1-10 scale).}
\item{elapsed_days}{Days since last review.}
\item{rating}{Review rating (1=Again, 2=Hard, 3=Good, 4=Easy).}
\item{desired_retention}{Target probability of recall (0-1).}
\item{params}{FSRS parameters (length 21), or NULL for defaults.}
}
\value{
List with updated \code{stability} and \code{difficulty}.
}
\note{
This is a low-level function. Consider using \code{\link{fsrs_next_memory_state}} instead.
}
\examples{
fsrs_next_state(10, 5, 10, 3, 0.9, NULL)
}
