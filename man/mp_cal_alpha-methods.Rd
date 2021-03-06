% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/method-get-alphaindex.R
\docType{methods}
\name{mp_cal_alpha}
\alias{mp_cal_alpha}
\alias{mp_cal_alpha,MPSE-method}
\alias{mp_cal_alpha,MPSE}
\alias{mp_cal_alpha,tbl_mpse-method}
\alias{mp_cal_alpha,tbl_mpse}
\alias{mp_cal_alpha,grouped_df_mpse-method}
\alias{mp_cal_alpha,grouped_df_mpse}
\title{calculate the alpha index with MPSE or tbl_mpse}
\usage{
mp_cal_alpha(
  .data,
  .abundance = NULL,
  action = c("add", "only", "get"),
  force = FALSE,
  ...
)

\S4method{mp_cal_alpha}{MPSE}(.data, .abundance = NULL, action = "add", force = FALSE, ...)

\S4method{mp_cal_alpha}{tbl_mpse}(.data, .abundance = NULL, action = "add", force = FALSE, ...)

\S4method{mp_cal_alpha}{grouped_df_mpse}(.data, .abundance = NULL, action = "add", force = FALSE, ...)
}
\arguments{
\item{.data}{MPSE or tbl_mpse object}

\item{.abundance}{The column name of OTU abundance column to be calculate}

\item{action}{character it has three options, "add" joins the new information 
to the input tbl (default), "only" return a non-redundant tibble with the just 
new information, ang 'get' return a 'alphasample' object.}

\item{force}{logical whether calculate the alpha index even the '.abundance' is 
not rarefied, default is FALSE.}

\item{...}{additional arguments}
}
\value{
update object or other (refer to action)
}
\description{
calculate the alpha index with MPSE or tbl_mpse
}
