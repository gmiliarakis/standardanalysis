#' @title ANCOMBC2 Wrappers
#'
#' @description Functions for running ANCOM-BC2 analyses and displaying results.
#'
#' @section Functions:
#' - `run_ancombc2()`: Runs ANCOM-BC2 analysis on microbiome data.
#' - `display_ancombc2_results()`: Displays the results in an optionally interactive table.
#'
#' @name ancombc2_wrappers
#' @export
ancombc2_params <- list(
  # Model formula parameters
  fixed_terms = "Timepoint + SubjectID", # Fixed effects formula
  random_terms = "(Timepoint | SubjectID)", # Random effects formula
  grouping_variable = NULL, # Grouping variable

  # General parameters
  n_cores = 16, # Number of CPU cores or clusters
  verbose = TRUE, # Verbose resultsput

  # Preprocessing parameters
  taxonomy_level = NULL, # Taxonomic level to be tested
  prevalence_cutoff = 0.1, # Prevalence cut-off
  library_size_cutoff = 1000, # Library size cut-off

  # Structural zeros parameters
  structural_zero = TRUE, # Detect structural zeros
  lower_bound = TRUE, # Classify a taxon as a structural zero using its asymptotic lower bound

  # Statistical parameters
  p_adj_method = "holm", # P-value (multiple testing) adjustment method
  alpha = 0.05, # Significance level
  iter = 10, # Number of REML AND EM iterations
  bootstrap = 10, # Number of bootstrap samples, should be 100+

  # Multi-group test parameters: set to FALSE if no grouping_variable!
  global = TRUE, # Perform global test
  pairwise = TRUE, # Perform pairwise tests
  dunnet = TRUE, # Perform Dunnett's test
  trend = TRUE, # Perform trend test

  # Pseudocount sensitivity analysis parameters
  pseudo_sens = TRUE, # Sensitivity analysis
  s0_perc = 0.05 # -th percentile of std. error values for each fixed effect (microarray sig.- SAM)
)

#' Run ANCOM-BC2 Analysis
#'
#' This function executes the ANCOM-BC2 analysis on a given phyloseq object using specified parameters.
#' ANCOM-BC2 is a differential abundance analysis method for microbiome data.
#'
#' @param ps A `phyloseq` object containing the microbiome data.
#' @param params A named list of parameters for the ANCOM-BC2 analysis. See Details for required parameters.
#'
#' @return A list containing the ANCOM-BC2 analysis results:
#' \itemize{
#'   \item \code{res_global}: Results from global tests.
#'   \item \code{res_pair}: Results from pairwise comparisons.
#'   \item \code{dunn}: Results from Dunnett's test.
#'   \item \code{res_trend}: Results from trend analysis.
#'   \item \code{res}: Primary analysis results.
#' }
#'
#' @details
#' The `params` list should contain the following elements:
#' \describe{
#'   \item{taxonomy_level}{Taxonomic level to be tested (e.g., "Genus").}
#'   \item{prevalence_cutoff}{Prevalence cut-off for filtering taxa.}
#'   \item{library_size_cutoff}{Library size cut-off for filtering samples.}
#'   \item{structural_zero}{Logical, whether to detect structural zeros.}
#'   \item{lower_bound}{Logical, whether to classify a taxon as a structural zero using its asymptotic lower bound.}
#'   \item{fixed_terms}{Formula specifying fixed effects.}
#'   \item{random_terms}{Formula specifying random effects.}
#'   \item{grouping_variable}{Grouping variable for multi-group tests.}
#'   \item{p_adj_method}{Method for p-value adjustment (e.g., "holm").}
#'   \item{alpha}{Significance level.}
#'   \item{global}{Logical, whether to perform a global test.}
#'   \item{pairwise}{Logical, whether to perform pairwise tests.}
#'   \item{dunnet}{Logical, whether to perform Dunnett's test.}
#'   \item{trend}{Logical, whether to perform a trend test.}
#'   \item{pseudo_sens}{Logical, whether to perform pseudocount sensitivity analysis.}
#'   \item{s0_perc}{Percentile of standard error values for sensitivity analysis.}
#'   \item{n_cores}{Number of CPU cores to use.}
#'   \item{verbose}{Logical, whether to print verbose resultsput.}
#'   \item{iter}{Number of iterations for REML and EM algorithms.}
#'   \item{bootstrap}{Number of bootstrap samples.}
#' }
#'
#' @examples
#' \dontrun{
#' result <- run_ancombc2(ps, ancombc2_params)
#' }
#'
#' @export
run_ancombc2 <- function(ps, params) {
  ANCOMBC::ancombc2(
    data = ps,
    tax_level = params$taxonomy_level,
    prv_cut = params$prevalence_cutoff,
    lib_cut = params$library_size_cutoff,
    struc_zero = params$structural_zero,
    neg_lb = params$lower_bound,
    fix_formula = params$fixed_terms,
    rand_formula = params$random_terms,
    group = params$grouping_variable,
    p_adj_method = params$p_adj_method,
    alpha = params$alpha,
    global = params$global,
    pairwise = params$pairwise,
    dunnet = params$dunnet,
    trend = params$trend,
    pseudo_sens = params$pseudo_sens,
    s0_perc = params$s0_perc,
    n_cl = params$n_cores,
    verbose = params$verbose,
    iter_control = list(tol = 1e-2, max_iter = params$iter, verbose = TRUE),
    em_control = list(tol = 1e-5, max_iter = params$iter),
    lme_control = lme4::lmerControl(),
    mdfdr_control = list(fwer_ctrl_method = "holm", B = params$bootstrap),
    trend_control = list(
      contrast = list(matrix(c(1, 0, -1, 1),
        nrow = 2, byrow = TRUE
      )),
      node = list(2), solver = "ECOS", B = params$bootstrap
    )
  )
}

#' Display ANCOM-BC2 Results as Tables or Data Frames
#'
#' Presents ANCOM-BC2 results as interactive tables (with DT) or plain data frames.
#'
#' @param results The output object from `ANCOMBC::ancombc2()`.
#' @param analyses Character vector: which results to display. Options: "global", "pairwise", "dunnett", "trend". Default NULL (primary only).
#' @param html Logical. If TRUE (default), returns DT::datatable for the primary analysis; if FALSE, returns data frames.
#' @return Named list of tables (either DT::datatable or data.frame for primary analysis).
#' @examples
#' \dontrun{
#' # In R Markdown:
#' tabs <- display_ancombc2_results(ancombc2_output, analyses = c("global", "pairwise"))
#' tabs$primary # Interactive DT table
#' tabs$global # Plain data frame
#' tabs$pairwise # Plain data frame
#' }
#' @export
display_ancombc2_results <- function(results, analyses = NULL, html = TRUE) {
  get_result <- function(results, result_name) {
    switch(result_name,
      "global"   = results$res_global,
      "pairwise" = results$res_pair,
      "dunnett"  = results$dunn,
      "trend"    = results$res_trend,
      NULL
    )
  }

  get_caption <- function(result_name) {
    switch(result_name,
      "global"   = "ANCOM-BC2 Global Test",
      "pairwise" = "ANCOM-BC2 Pairwise Comparison",
      "dunnett"  = "ANCOM-BC2 Dunnett's Test",
      "trend"    = "ANCOM-BC2 Trend Analysis",
      "primary"  = "ANCOM-BC2 Primary Analysis"
    )
  }

  process_table <- function(df, caption, as_datatable = FALSE) {
    numeric_cols <- sapply(df, is.numeric)
    df[numeric_cols] <- lapply(df[numeric_cols], signif, 3)
    if (as_datatable) {
      DT::datatable(df, caption = caption, options = list(scrollX = TRUE, dom = "tpr"))
    } else {
      df
    }
  }

  out <- list()
  # Primary as DT::datatable
  out$primary <- process_table(results$res, get_caption("primary"), as_datatable = html)

  # Others optionally as plain data frames
  valid <- c("global", "pairwise", "dunnett", "trend")
  if (!is.null(analyses)) {
    for (result in analyses) {
      if (result %in% valid) {
        temp_res <- get_result(results, result)
        out[[result]] <- process_table(temp_res, get_caption(result), as_datatable = html)
      } else {
        stop("Invalid analysis: ", result, ". Valid options: ", paste(valid, collapse = ", "))
      }
    }
  }
  return(out)
}
