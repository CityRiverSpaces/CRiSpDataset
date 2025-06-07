library(rcrisp)
library(dplyr)
library(lwgeom)
library(sf)

# Set input parameters
CITY_RIVERS_FILEPATH <- file.path("output", "city_rivers.csv")
SEGMENT_DIR <- file.path("output", "segments")
FEATURES_DIR <- file.path("output", "features")
OUTPUT_METRICS_FILEPATH <- file.path("output", "city_rivers_metrics.csv")


run <- function(city_rivers_filepath, segments_dir, features_dir,
                output_metrics_filepath) {
  # Load city river table as a data frame
  city_rivers <- read.csv(city_rivers_filepath)

  # Loop over the cities and retrieve the features for the available segments
  for (n in seq_len(nrow(city_rivers))) {
    cr <- city_rivers[n, ]
    city_name <- cr$city_name
    river_name <- cr$river_name
    segments <- load_vector_data(city_name, river_name, dir = segments_dir)
    if (is.null(segments)) next
    features <- get_features(city_name, river_name, segments,
                             dir = features_dir)
    metrics <- compute_metrics(features)
  }

  # write.csv(metrics, output_metrics_filepath)
}

get_features <- function(city_name, river_name, segments, dir = ".") {
  # OSM features
  streets <- load_vector_data(city_name, river_name, suffix = "streets", dir = dir)
  railways <- load_vector_data(city_name, river_name, suffix = "railways", dir = dir)
  buildings <- load_vector_data(city_name, river_name, suffix = "buildings", dir = dir)
  river_centerline <- load_vector_data(city_name, river_name, suffix = "river", layer = "centerline", dir = dir)
  river_surface <- load_vector_data(city_name, river_name, suffix = "river", layer = "surface", dir = dir)

  # Derived features
  corridor <- st_union(segments)
  composite <- get_composite(buildings)
  sanctuary_polygons <- get_sanctuary_polygons(corridor, streets)

  # Return all features
  list(
    # OSM features
    streets = streets,
    railways = railways,
    buildings = buildings,
    river_centerline = river_centerline,
    river_surface = river_surface,
    # Derived OSM features
    composite = composite,
    sanctuary_polygons = sanctuary_polygons,
    # CRiSp features
    corridor = corridor,
    segments = segments
  )
}

load_vector_data <- function(city_name, river_name, suffix = NULL, dir = ".",
                             layer = NULL, ext = "gpkg") {
  filepath <- get_filepath(city_name, river_name, suffix = suffix, dir = dir, ext = ext)
  if (file.exists(filepath)) {
    # For some reason, calling st_read with layer = NULL fails
    if (is.null(layer)) {
      st_read(filepath, quiet = TRUE)
    } else {
      st_read(filepath, layer = layer, quiet = TRUE)
    }
  } else {
    NULL
  }
}

get_filepath <- function(city_name, river_name, suffix = NULL, dir = ".", ext = "gpkg") {
  stem <- paste(city_name, river_name, sep = "_")
  if (!is.null(suffix)) stem <- stem <- paste(stem, suffix, sep = "_")
  filename <- paste(stem, ext, sep = ".")
  file.path(dir, filename)
}

get_composite <- function(buildings) {
  buildings |>
    st_union() |>
    st_cast("POLYGON")
}

get_sanctuary_polygons <- function(corridor, streets) {
  main_streets <- streets |>
    filter(type %in% c("motorway", "trunk", "primary", "secondary", "tertiary"))
  st_split(corridor, main_streets) |>
    st_collection_extract()
}

#' Calculate metrics for available cities
compute_metrics <- function(features) {
  print("Done")
}

# Call the main function
run(CITY_RIVERS_FILEPATH, SEGMENT_DIR, FEATURES_DIR, OUTPUT_METRICS_FILEPATH)
