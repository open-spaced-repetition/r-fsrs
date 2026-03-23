\name{fsrs_next_interval}
\alias{fsrs_next_interval}
\title{Calculate Next Review Interval}
\description{
Calculates the optimal interval until the next review based on current
memory stability and desired retention rate.
}
\usage{
fsrs_next_interval(stability, desired_retention, params)
}
\arguments{
\item{stability}{Current memory stability in days.}
\item{desired_retention}{Target probability of recall (0-1).}
\item{params}{FSRS parameters (length 21), or NULL for defaults.}
}
\value{
Integer interval in days until next review.
}
\note{
This is a low-level function. Consider using \code{\link{fsrs_interval}} instead.
}
\examples{
fsrs_next_interval(10, 0.9, NULL)
}
