\name{fsrs_next_state}
\alias{fsrs_next_state}
\title{Calculate Next Memory State}
\description{
Updates memory state after a review, calculating new stability and difficulty.
}
\usage{
fsrs_next_state(stability, difficulty, elapsed_days, rating, params = NULL)
}
\arguments{
\item{stability}{Current memory stability in days.}
\item{difficulty}{Current difficulty (1-10 scale).}
\item{elapsed_days}{Days since last review.}
\item{rating}{Review rating (1=Again, 2=Hard, 3=Good, 4=Easy).}
\item{params}{Optional custom FSRS parameters (length 21). Uses defaults if NULL.}
}
\value{
List with updated \code{stability} and \code{difficulty}.
}
\examples{
fsrs_next_state(10, 5, 10, 3)
}
