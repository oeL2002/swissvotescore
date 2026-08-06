#' @noRd
check_geolevel <- function(geolevel, available_geolevels) {
  
  if (!geolevel %in% available_geolevels) stop("Please select valid 'geolevel'.")
  
}

#' @noRd
check_language <- function(language, available_languages) {
  
  if (!language %in% available_languages) stop("Please select valid 'language'.")
  
}

