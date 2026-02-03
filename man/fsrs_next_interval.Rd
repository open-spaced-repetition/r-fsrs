\name{fsrs_next_interval}
\alias{fsrs_next_interval}
\title{Calculate Next Review Interval}
\description{
Calculates the optimal interval until the next review based on current
memory stability and desired retention rate.
}
\usage{
fsrs_next_interval(stability, desired_retention, params = NULL)
}
\arguments{
\item{stability}{Current memory stability in days.}
\item{desired_retention}{Target probability of recall (0-1).}
\item{params}{Optional custom FSRS parameters (length 21). Uses defaults if NULL.}
}
\value{
Integer interval in days until next review.
}
\examples{
fsrs_next_interval(10, 0.9)
fsrs_next_interval(30, 0.9)
}
