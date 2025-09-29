#' Retry function call, for interaction with APIs and external services
#'
#' @param func function
#' @param ... additional keyword parameters passed on to `func`
#' @param max_retries int
#' @param delay numeric
#' @return the output of `func`
retry <- function(func, ..., max_retries = 5, delay = 2) {
  attempt <- 1
  while (attempt <= max_retries) {
    result <- tryCatch({
      func(...)  # Call the function with arguments
    }, error = function(e) {
      message(sprintf("Attempt %d failed: %s", attempt, e$message))
      NULL
    })

    if (!is.null(result)) {
      return(result)  # Successfully retrieved result
    }

    message(sprintf("Retrying in %d seconds...", delay))
    Sys.sleep(delay)
    attempt <- attempt + 1
  }

  message("Function failed after multiple attempts.")
  NULL
}
