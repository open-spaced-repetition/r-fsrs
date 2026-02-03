\name{fsrs_initial_state}
\alias{fsrs_initial_state}
\title{Get Initial Memory State}
\description{
Calculates the initial stability and difficulty for a new card after its
first review.
}
\usage{
fsrs_initial_state(rating, params = NULL)
}
\arguments{
\item{rating}{First rating (1=Again, 2=Hard, 3=Good, 4=Easy).}
\item{params}{Optional custom FSRS parameters (length 21). Uses defaults if NULL.}
}
\value{
List with \code{stability} and \code{difficulty}.
}
\examples{
fsrs_initial_state(3)
fsrs_initial_state(1)
}
