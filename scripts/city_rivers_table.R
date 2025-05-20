library(CRiSp)
library(dplyr)
library(sf)
library(stringr)


POPULATION_FILEPATH <- file.path("data", "estat_urb_cpop1_en.csv")
POPULATION_THRESHOLD <- 250000
OUTPUT_FILEPATH <- file.path("output", "city_rivers.csv")


#' Find cities whose population is above a given threshold
#'
#' Load and clean the file POPULATION_FILEPATH
#'
#' @param population_filepath string
#' @param population_threshold int
#' @return data frame
get_cities <- function(population_filepath, population_threshold) {
  read.csv(population_filepath) |>
    # The "DE1001V" variable code refers to "Population on the 1st of January,
    # total"
    filter(indic_ur == "DE1001V") |>
    # Select cities, which have a 6-character code. We thus drop country-level
    # statistics (countries have a 2-character code)
    filter(nchar(cities) == 6) |>
    # Find the most recent population records (TIME_PERIOD is the year)
    group_by(cities) |>
    filter(TIME_PERIOD == max(TIME_PERIOD, na.rm = TRUE)) |>
    ungroup() |>
    # Filter population for the given threshold
    filter(OBS_VALUE > population_threshold) |>
    # Rename and select relevant columns
    rename(city_name = Geopolitical.entity..declaring.,
           population = OBS_VALUE,
           year = TIME_PERIOD) |>
    select(city_name, population, year) |>
    # Drop "greater cities" from the city names
    mutate(city_name = str_replace(city_name, "\\ \\(greater\\ city\\)", "")) |>
    # Fix name so that it can be found by the Nominatim API
    mutate(city_name = str_replace(
      city_name,
      "North\\ Lanarkshire\\ \\(Airdrie\\/Bellshill\\/Coatbridge\\/Motherwell\\)",
      "North\\ Lanarkshire"
    )) |>
    # Replaces "/" with "-" to avoid problems with directory separators
    mutate(city_name = str_replace(city_name, "/", "-"))
}

#' Get name of the longest "waterway:river" feature within a bbox
#'
#' The OverPass API is queried and results are cached to disk. If no feature is
#' found, NA is returned
#'
#' @param bb [`sf::bbox`] object
#' @param force_download bool, if TRUE the Overpass API is queried even if
#'   results from a prevuous query are available in  the cache
#' @return string
get_river_name <- function(bb, force_download = FALSE) {
  osm_data <- osmdata_as_sf("waterway", "river", bb, force_download = force_download)
  # If we have no features, or no feature has a name, return NA
  if (is.null(osm_data$osm_lines) || all(is.null(osm_data$osm_lines$name))) {
    return(NA)
  } else {
    longest_river <- osm_data$osm_lines |>
      # Crop river to area of interest
      st_crop(bb) |>
      # Only consider LINESTRINGS and MULTILINESTRINGS
      filter(st_geometry_type(geometry) %in% c("LINESTRING", "MULTILINESTRING")) |>
      # Group by OSM names
      group_by(name) |>
      summarize() |>
      # Calculate length of aggregated geometries
      mutate(length = st_length(geometry)) |>
      # Find longest segment
      filter(length == max(length))
    return(longest_river$name)
  }
}

# Load and clean the city population data frame
city_rivers <- get_cities(POPULATION_FILEPATH, POPULATION_THRESHOLD)
# Retrieve bounding boxes
bbs <- lapply(city_rivers$city_name, get_osm_bb)
# Find the main rivers intersecting the cities
city_rivers["river_name"] <- sapply(bbs, get_river_name, simplify = TRUE)
# Convert bounding box list to data frame, and merge to the data frame
bbs_df <- as.data.frame(do.call(rbind, bbs))
city_rivers <- cbind(city_rivers, bbs_df)
# Drop cities without a river
city_rivers <- filter(city_rivers, !is.na(river_name))
# Write data frame as CSV
write.csv(city_rivers, OUTPUT_FILEPATH)
