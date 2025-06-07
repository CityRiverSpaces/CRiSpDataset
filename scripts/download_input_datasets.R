library(rcrisp)
library(dplyr)
library(sf)
library(terra)

# Set input parameters
CITY_RIVERS_FILEPATH <- file.path("output", "city_rivers.csv")
NETWORK_BUFFER <- 3500
DEM_BUFFER <- 2500
OUTPUT_OSM_DIR <- file.path("output", "osm")
OUTPUT_DEM_DIR <- file.path("output", "dem")

run <- function(city_rivers_filepath, network_buffer = 3500, dem_buffer = 2500,
                output_osm_dir = "osm", output_dem_dir = "dem") {
  # Load city rivers as a data frame
  city_rivers <- read.csv(CITY_RIVERS_FILEPATH)

  # Loop over the cities and retrieve the input data
  for (n in seq_len(nrow(city_rivers))) {
    cr <- city_rivers[n, ]
    city_name <- cr$city_name
    river_name <- cr$river_name
    bb <- st_bbox(c(xmin = cr$xmin,
                    xmax = cr$xmax,
                    ymin = cr$ymin,
                    ymax = cr$ymax),
                  crs = 4326)
    print(sprintf("%d - retrieve data for: %s - %s", n, city_name, river_name))
    retrieve_data(city_name, river_name, bb)
  }
}

retrieve_data <- function(city_name, river_name, bb, force_download = FALSE) {
  # Define output filenames
  stem <- paste(city_name, river_name, sep = "_")
  osm_filepath <- file.path(OUTPUT_OSM_DIR, paste(stem, "gpkg", sep = "."))
  dem_filepath <- file.path(OUTPUT_DEM_DIR, paste(stem, "tif", sep = "."))
  if (file.exists(osm_filepath) && file.exists(dem_filepath)) {
    message(sprintf("Files for %s / %s exist - skipping it.",
                    city_name, river_name))
    return()
  }
  # Define projected coordinate reference system for the area
  crs <- get_utm_zone(bb)

  # Retrieve and write OSM data
  river <- get_river(river_name, bb, force_download = force_download)
  aoi_network <- st_buffer(st_crop(river, bb), NETWORK_BUFFER)
  network <- get_network(aoi_network, force_download = force_download)
  write_osm(c(network, list(river = river)), osm_filepath, crs = crs)

  # Retrieve and write DEM data
  aoi_dem <- st_buffer(aoi_network, DEM_BUFFER)
  dem <- get_dem(aoi_dem, force_download = force_download)
  write_dem(dem, dem_filepath, crs = crs)
}

get_river <- function(river_name, bb, force_download = force_download) {
  osm <- osmdata_as_sf("waterway", "river", bb, force_download = force_download)
  lines <- osm$osm_lines
  if (!is.null(osm$osm_multilines)) lines <- bind_rows(lines,
                                                       osm$osm_multilines)
  lines |>
    filter(if_any(matches("name"), \(x) x == river_name)) |>
    # the query can return more features than actually intersecting the bb
    st_filter(st_as_sfc(bb), .predicate = st_intersects) |>
    st_geometry() |>
    st_union()
}

get_osm_railways <- function(aoi, crs = NULL, force_download = FALSE) {
  railways <- osmdata_as_sf("railway", "rail", aoi,
                            force_download = force_download)
  # If no railways are found, return an empty sf object
  if (is.null(railways$osm_lines)) {
    if (is.null(crs)) crs <- sf::st_crs("EPSG:4326")
    empty_sf <- sf::st_sf(geometry = sf::st_sfc(crs = crs))
    return(empty_sf)
  }

  railways_lines <- railways$osm_lines |>
    dplyr::select("railway") |>
    dplyr::rename(!!sym("type") := !!sym("railway"))

  # Intersect with the bounding polygon
  if (inherits(aoi, "bbox")) aoi <- sf::st_as_sfc(aoi)
  mask <- sf::st_intersects(railways_lines, aoi, sparse = FALSE)
  railways_lines <- railways_lines[mask, ]

  if (!is.null(crs)) railways_lines <- sf::st_transform(railways_lines, crs)

  railways_lines
}

get_network <- function(aoi, force_download) {
  list(
    streets = get_osm_streets(aoi, force_download = force_download),
    railways = get_osm_railways(aoi, force_download = force_download)
  )
}

write_osm <- function(data, filepath, crs = NULL) {
  # Make sure directory exists
  dir.create(dirname(filepath), showWarnings = FALSE)
  # Create new file for the first layer ...
  append <- FALSE
  for (name in names(data)) {
    if (!is.null(crs)) obj <- st_transform(data[[name]], crs)
    st_write(obj, filepath, layer = name, append = append)
    # ... then append existing layers in the existing file
    append <- TRUE
  }
}

write_dem <- function(data, filepath, crs = NULL) {
  # Make sure directory exists
  dir.create(dirname(filepath), showWarnings = FALSE)
  if (!is.null(crs)) obj <- project(data, crs(paste("EPSG", crs, sep = ":")))
  writeRaster(obj, filepath)
}

# Call the main function
run(CITY_RIVERS_FILEPATH,
    network_buffer = NETWORK_BUFFER,
    dem_buffer = DEM_BUFFER,
    output_osm_dir = OUTPUT_OSM_DIR,
    output_dem_dir = OUTPUT_DEM_DIR)
