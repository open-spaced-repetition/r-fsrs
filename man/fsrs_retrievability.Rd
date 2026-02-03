\name{fsrs_retrievability}
\alias{fsrs_retrievability}
\title{Calculate Retrievability}
\description{
Calculates the probability of recalling a card given its stability and
time since last review.
}
\usage{
fsrs_retrievability(stability, elapsed_days)
}
\arguments{
\item{stability}{Memory stability in days.}
\item{elapsed_days}{Days since last review.}
}
\value{
Probability of recall (0-1).
}
\examples{
fsrs_retrievability(10, 10)
fsrs_retrievability(10, 20)
}
