#' Transform a opendata.swiss cantonal results json into a tibble
#'
#' \code{canton_json_to_dfr} tranforms a single results json for a selected cantonal votedate into a tibble.
#'
#' @param x path to a cantonal results json previously downloaded from opendata.swiss,
#'   or the already-parsed json. The caller decides where the bytes come from; this
#'   function performs no network access.
#' @param votedate date of the ballot. Required. Format = YYYY-MM-DD
#' @param geolevel geographical level for which the results should be loaded. Options: "canton", "district" or "municipality".
#'
#' @importFrom jsonlite fromJSON
#' @importFrom tibble tibble
#' @importFrom purrr map
#' @importFrom dplyr "%>%" filter bind_rows rename left_join
#' @importFrom tidyr unnest unpack
#' @importFrom lubridate ymd
#' 
#' @return a tibble containing the results
#' 
#' @export
#' 
#' @examples
#' \dontrun{
#' # Transform an archived cantonal results json
#' canton_json_to_dfr("kantonale_2020-02-09.json", votedate = "2020-02-09")
#' }
canton_json_to_dfr <- function(x, votedate, geolevel = "municipality") {

  # Check inputs
  check_geolevel(geolevel, available_geolevels = c("canton", "district", "municipality", "zh_counting_districts"))
  if (missing(votedate)) stop("'votedate' is required: it cannot be inferred from a local file.")

  # Read the vote data: a path to parse, or already-parsed json
  res_data <- if (is.character(x)) suppressWarnings(jsonlite::fromJSON(x)) else x

  if(!is.null(res_data)){
  
  # Simplification
  data_cantons <- res_data[["kantone"]]
  
  # Geolevel specific extraction
  if (geolevel == "canton") {
    
    ktdata2 <- tibble::tibble(
      canton_name = data_cantons[["geoLevelname"]],
      id = purrr::map(data_cantons[["vorlagen"]], 1),
      resultat = purrr::map(data_cantons[["vorlagen"]], "resultat")
      ) %>% 
      tidyr::unnest(c(id, resultat))
    
  }
  if (!(geolevel == "canton")) {
    
    # Switch
    switch(
      geolevel,
      municipality = {geoindex <- "gemeinden"},
      zh_counting_districts = {geoindex <- "gemeinden"},
      district = {geoindex <- "bezirke"}
      )
    
    ## tibble with data
    ktdata <- tibble::tibble(
      id = purrr::map(data_cantons[["vorlagen"]], 1),
      canton_name = data_cantons[["geoLevelname"]],
      res = purrr::map(data_cantons[["vorlagen"]], geoindex)
      ) %>%  
      tidyr::unnest(c(id, res)) %>% 
      tidyr::unnest(res) %>% 
      tidyr::unpack(resultat)
    
    # Zaehlkreisdaten einlesen (nur falls vorhanden)
    if (geolevel == "zh_counting_districts" & is.list(data_cantons$vorlagen[[1]]$zaehlkreise)) {
      
      zaehlkreise <- tibble::tibble(
        id = purrr::map(data_cantons[["vorlagen"]], 1),
        canton_name = data_cantons[["geoLevelname"]],
        res = purrr::map(data_cantons[["vorlagen"]], "zaehlkreise")
        ) %>% 
        tidyr::unnest(c(id, res)) %>% 
        tidyr::unnest(res) %>% 
        tidyr::unpack(resultat)
      
    }
    
  }
  if (geolevel == "district") ktdata2 <- ktdata %>% dplyr::rename(district_id = geoLevelnummer, district_name = geoLevelname)
  if (geolevel %in% c("municipality","zh_counting_districts")) ktdata2 <- ktdata %>% dplyr::rename(mun_id = geoLevelnummer, mun_name = geoLevelname)
  if (geolevel == "zh_counting_districts" & is.list(data_cantons$vorlagen[[1]]$zaehlkreise)) {
    
    # remove winterthur and zurich as single municipalities
    ktdata2 <-  ktdata2 %>% 
      dplyr::filter(!mun_id %in% c(261,230)) %>% 
      dplyr::bind_rows(zaehlkreise %>% dplyr::rename(mun_id = geoLevelnummer, mun_name = geoLevelname))
    
  }
  
  # vote names in all languages
  canton_vote_names <- tibble::tibble(
    id = purrr::map(data_cantons[["vorlagen"]], 1),
    yes = purrr::map(c(1:length(data_cantons[["vorlagen"]])), ~data_cantons[["vorlagen"]][[.x]]$vorlagenTitel)
    ) %>%
    # unnest lists with ids and the vote-names
    tidyr::unnest(c(id, yes)) %>%
    # unnest list with language versions
    tidyr::unnest(yes) %>%
    #spread to wide to join descriptions to data
    tidyr::spread(langKey, text)
  
  # join vote names to result
  ktdata3 <- ktdata2 %>% dplyr::left_join(canton_vote_names, by = "id")
  
  # Add votedate
  ktdata3$votedate <- lubridate::ymd(votedate)
  
  # Return
  return(ktdata3)
  
    }
  }