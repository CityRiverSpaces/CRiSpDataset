library(CRiSp)
library(dplyr)
library(sf)
library(sfnetworks)
library(terra)
library(tidygraph)

# Load command line arguments
ARGS <- commandArgs(trailingOnly = TRUE)

#' Main access point of the script
#'
#' Run the corridor and segment delineation and save the computed
#' geometries to a vector data file.
#'
#' @param vector_filepath string
#' @param dem_filepath string
#' @param output_filepath string
run <- function(vector_filepath, dem_filepath, output_filepath) {
  segments <- delineate_city(vector_filepath, dem_filepath)
  write_output(segments, output_filepath)
}

#' Run the corridor and segment delineations
#'
#' @param vector_filepath string
#' @param dem_filepath string
delineate_city <- function(vector_filepath, dem_filepath) {
  # Load required input datasets
  data <- load_data(vector_filepath, dem_filepath)

  # Build spatial network using street and railways
  network <- build_network(data$streets, data$railways)

  # Run corridor delineation
  corridor <- delineate_corridor(network,
                                 data$river,
                                 max_width = 3000,
                                 initial_method = "valley",
                                 buffer = NULL,
                                 dem = data$dem,
                                 max_iterations = 10,
                                 capping_method = "shortest-path")

  # Limit the network to the corridor region for the segment delineation
  network_filtered <- filter_network(network, corridor, buffer = 100)

  # Run delineation and return segmented corridor
  delineate_segments(corridor, network_filtered, data$river)
}

#' Load input datasets
#'
#' Load all vector layers (streets, railways, river) and the raster digital
#' elevation model (DEM)
#'
#' @param vector_filepath string
#' @param dem_filepath string
load_data <- function(vector_filepath, dem_filepath) {
  # Load vector dataset
  layers <- st_layers(vector_filepath)
  vec_data <- sapply(layers$name,
                     \(x) st_read(vector_filepath, layer = x, quiet = TRUE))

  # Load raster DEM
  dem <- rast(dem_filepath)

  # Returned named list with all input datasets
  c(vec_data, dem = dem)
}

#' Build the spatial newtork from the street and (optionally) railway lines
#'
#' @param streets [`sf::sf`] or [`sf::sfc`] object
#' @param railways [`sf::sf`] or [`sf::sfc`] object
build_network <- function(streets, railways = NULL) {
  network_edges <- streets
  if (!is.null(railways)) network_edges <- bind_rows(network_edges, railways)
  as_network(network_edges)
}

#' Select the only part of the network within the corridor (plus buffer)
#'
#' @param network [`sfnetworks::sfnetwork`] object
#' @param streets [`sf::sf`] or [`sf::sfc`] object
#' @param buffer numeric
filter_network <- function(network, corridor, buffer = 100) {
  corridor_buffer <- sf::st_buffer(corridor, buffer)
  network |>
    activate("nodes") |>
    filter(node_intersects(corridor_buffer)) |>
    # keep only the main connected component of the network
    activate("nodes") |>
    filter(group_components() == 1)
}

#' Save feature to a vector data file
#'
#' If the output file exists, overwrite it.
#'
#' @param feature [`sf::sf`] or [`sf::sfc`] object
#' @param output_filepath string
write_output <- function(feature, output_filepath) {
  dir.create(dirname(output_filepath), showWarnings = FALSE)
  st_write(feature, output_filepath, append = FALSE, quiet = TRUE)
}

# Call the main function
if (length(ARGS) == 3) {
  run(vector_filepath = ARGS[1],
      dem_filepath = ARGS[2],
      output_filepath = ARGS[3])
}
