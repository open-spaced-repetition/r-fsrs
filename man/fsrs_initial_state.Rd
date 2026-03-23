\name{fsrs_initial_state}
\alias{fsrs_initial_state}
\title{Get Initial Memory State}
\description{
Calculates the initial stability and difficulty for a new card after its
first review.
}
\usage{
fsrs_initial_state(rating, params)
}
\arguments{
\item{rating}{First rating (1=Again, 2=Hard, 3=Good, 4=Easy).}
\item{params}{FSRS parameters (length 21), or NULL for defaults.}
}
\value{
List with \code{stability} and \code{difficulty}.
}
\note{
This is a low-level function. Consider using \code{\link{fsrs_new_card_state}} instead.
}
\examples{
fsrs_initial_state(3, NULL)
}
