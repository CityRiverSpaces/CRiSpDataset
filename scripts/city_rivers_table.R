library(dplyr)
library(osmdata)
library(rcrisp)
library(sf)
library(stringr)

# Increase timeout
options(timeout = 300)

POPULATION_FILEPATH <- file.path("data", "estat_urb_cpop1_en.csv")
POPULATION_THRESHOLD <- 250000
OUTPUT_FILEPATH <- file.path("output", "city_rivers.csv")


#' Main access point of the script
#'
#' Clean the Eurostat city population dataset
#' (https://ec.europa.eu/eurostat/web/regions-and-cities) to identify urban
#' areas with population above a certain threshold, identify main water streams
#' in the urban areas (when present) and save output data frame to a CSV file.
#'
run <- function(population_filepath, population_threshold, output_filepath) {
  # Load and clean the city population data frame
  city_rivers <- get_cities(population_filepath, population_threshold)
  # Retrieve bounding boxes
  bbs <- lapply(city_rivers$city_name, get_bb)
  # Find the main rivers intersecting the cities
  city_rivers["river_name"] <- sapply(bbs, get_river_name, simplify = TRUE)
  # Convert bounding box list to data frame, and merge to the data frame
  bbs_df <- as.data.frame(do.call(rbind, bbs))
  city_rivers <- cbind(city_rivers, bbs_df)
  # Drop cities without a river
  city_rivers <- filter(city_rivers, !is.na(river_name))
  # Write data frame as CSV
  write.csv(city_rivers, OUTPUT_FILEPATH)
}

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
    # Drop content of parentheses
    mutate(city_name = str_remove(city_name, " \\s*\\([^\\)]+\\)")) |>
    # Greater Valletta -> Valletta
    mutate(city_name = str_replace(city_name,
                                   "Greater\\ Valletta",
                                   "Valletta")) |>
    # Denizli -> Denizli, Pamukkale (avoid conflict with province)
    mutate(city_name = str_replace(city_name,
                                   "Denizli",
                                   "Denizli,\\ Pamukkale")) |>
    # When double names are given (using "/" as separator), only consider
    # first one
    mutate(city_name = str_remove(city_name, "/.*$"))
}

#' Determine the bounding box for a given city
#'
#' We take the bounding box as returned by the Nominatim API, and apply a
#' refinement step to drop disjoint polygons from the main "core" of the city.
#' This is to solve situations where a disjoint and isolated polygon feature
#' blows up the city bounding box to a huge extend (see e.g.
#' https://nominatim.openstreetmap.org/ui/search.html?q=hamburg)
#'
#' @param city_name string
#' @return sf bounding box object
get_bb <- function(city_name) {
  # Retrieve the bounding box from the Nominatim API, including information from
  # the OSM entry which it refers to
  df <- getbb(city_name, format_out = "data.frame")

  # Consider only the first of the (potentially longer) list of entries, and
  # extract the bounding box ("raw" bounding box), OSM ID and OSM type of the
  # feature it belongs to
  bb_raw <- as.numeric(df[[1, "boundingbox"]])
  names(bb_raw) <- c("ymin", "ymax", "xmin", "xmax")
  bb_raw <- st_bbox(bb_raw, crs = "EPSG:4326")
  osm_type <- df[1, "osm_type"]
  osm_id <- as.character(df[1, "osm_id"])

  # Retrieve the OSM entry linked to the bounding box using its ID and type.
  osm <- opq_osm_id(type = osm_type, id = osm_id) |>
    opq_string() |>
    osmdata_sf()

  # Extract the POLYGON and MULTIPOLYGON features of the OSM entry, and
  # stack them in a [`sf::sfc`] object
  boundaries <- c(osm$osm_polygons$geometry, osm$osm_multipolygons$geometry)

  # Some OSM entries do not have (MULTI)POLYGON features, in which case we
  # return the "raw" bounding box. We otherwise use the feature geometries to
  # try and refine the city boundary
  if (is.null(boundaries) || length(boundaries) == 0) {
    bb_raw
  } else {
    extract_refined_bb(boundaries)
  }
}

#' Extract the "refined" bounding box from administrative boundaries
#'
#' From all the given features, we identify the largest POLYGON, and drop all
#' disjoint geometries.
#'
#' @param boundaries [`sf::sfc`] object
extract_refined_bb <- function(boundaries) {
  # The city boundary might include several disjoint polygons. By casting to
  # POLYGON, then LINESTRING, and then POLYGON again, we separate the geometries
  boundaries <- boundaries |>
    st_cast("POLYGON") |>
    st_cast("LINESTRING") |>
    st_cast("POLYGON")

  # We calculate the area for each polygon and select the largest one
  boundaries |>
    st_as_sf() |>
    st_make_valid() |>  # make sure all polygons are valid!
    mutate(area = st_area(x)) |>
    filter(area == max(area)) |>
    st_bbox()
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
    # When two names are given with "/" as separator, only consider the first
    river_name <- str_remove(longest_river$name, "/.*$")
    return(river_name)
  }
}

# Call the main function
run(POPULATION_FILEPATH, POPULATION_THRESHOLD, OUTPUT_FILEPATH)
