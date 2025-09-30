library(rcrisp)
library(dplyr)
library(sf)

# Set input parameters
CITY_RIVERS_FILEPATH <- file.path("/output", "city_rivers.csv")
SEGMENTS_DIR <- file.path("/output", "segments")
OUTPUT_FILEPATH <- file.path("/output", "crisp-dataset.gpkg")


#' Main access point of the script
#'
#' @param city_rivers_filepath string
#' @param segment_dir string
#' @param output_filepath string
run <- function(city_rivers_filepath, segment_dir, output_filepath) {
  # Load city river table as a data frame
  city_rivers <- read.csv(city_rivers_filepath)

  # Loop over the cities and load the available segments
  crisp_dataset <- NULL
  for (n in seq_len(nrow(city_rivers))) {
    cr <- city_rivers[n, ]
    segments <- load_segments(cr$city_name, cr$river_name, segment_dir)
    if (is.null(segments)) next
    # Set segment geometries in lat/lon, so that we can merge all results
    segments <- st_transform(segments, "EPSG:4326")
    crisp_dataset <- bind_rows(crisp_dataset, segments)
  }
  # Print success rate
  message(sprintf("Successfully delineated: %s / %s cities ",
                  length(unique(crisp_dataset$city_name)),
                  nrow(city_rivers)))

  # Write out dataset
  st_write(crisp_dataset, output_filepath, quiet = TRUE, append = FALSE)
}

#' Load the delineation of a city
#'
#' @param city_name string
#' @param river_name string
#' @param segment_dir string
#' @return [`sf::sf`] or NULL if the segment file does not exist
load_segments <- function(city_name, river_name, segment_dir) {
  # Determine file path
  filepath <- file.path(segment_dir,
                        sprintf("%s_%s.gpkg", city_name, river_name))

  # Load segment data if file is present
  if (file.exists(filepath)) {
    segments <- st_read(filepath, quiet = TRUE)
    segments["city_name"] <- city_name
    segments["river_name"] <- river_name
    segments
  } else {
    NULL
  }
}

# Call the main function
run(CITY_RIVERS_FILEPATH, SEGMENTS_DIR, OUTPUT_FILEPATH)
