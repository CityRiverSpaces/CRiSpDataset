library(CRiSp)
library(dplyr)
library(sf)
library(terra)


CITY_RIVERS_FILEPATH <- file.path("output", "city_rivers.csv")
NETWORK_BUFFER <- 3500
DEM_BUFFER <- 2500
OUTPUT_OSM_DIR <- file.path("output", "osm")
OUTPUT_DEM_DIR <- file.path("output", "dem")


retrieve_data <- function(city_name, river_name, bb, force_download = FALSE) {
  # Define output filenames
  stem <- paste(city_name, river_name, sep = "_")
  osm_filepath <- file.path(OUTPUT_OSM_DIR, paste(stem, "gpkg", sep = "."))
  dem_filepath <- file.path(OUTPUT_DEM_DIR, paste(stem, "tif", sep = "."))
  if (file.exists(osm_filepath) && file.exists(dem_filepath)) return()

  # The city might include several disconnected polygons. Refine the bounding
  # box to focus on the largest polygon
  bb_refined <- refine_bb(bb, city_name)

  # Define projected coordinate reference system for the area
  crs <- get_utm_zone(bb_refined)

  # Retrieve and write OSM data
  river <- get_river(river_name, bb_refined, force_download = force_download)
  aoi_network <- st_buffer(st_crop(river, bb_refined), NETWORK_BUFFER)
  network <- get_network(aoi_network, force_download = force_download)
  write_osm(c(network, list(river = river)), osm_filepath, crs = crs)

  # Retrieve and write DEM data
  aoi_dem <- st_buffer(aoi_network, DEM_BUFFER)
  dem <- get_dem(aoi_dem, force_download = force_download)
  write_dem(dem, dem_filepath, crs = crs)
}

refine_bb <- function(bb, city_name, force_download = FALSE) {
  bound <- get_osm_city_boundary(bb, city_name, force_download = force_download)

  # The city boundary might include several disjoint polygons. By casting to
  # POLYGON, then LINESTRING, and then POLYGON again, we separate the geometries
  bound <- bound |>
    st_cast("POLYGON") |>
    st_cast("LINESTRING") |>
    st_cast("POLYGON")

  # We calculate the area for each polygon and select the largest one
  bound |>
    st_as_sf() |>
    mutate(area = st_area(x)) |>
    filter(area == max(area)) |>
    st_bbox()
}

get_river <- function(river_name, bb, force_download = force_download) {
  osm <- osmdata_as_sf("waterway", "river", bb, force_download = force_download)
  bind_rows(osm$osm_lines, osm$osm_multilines) |>
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

# Load city rivers as a data frame
city_rivers <- read.csv(CITY_RIVERS_FILEPATH)

# Loop over the cities and retrieve the input data
for (n in seq_len(nrow(city_rivers))) {
  cr <- city_rivers[n, ]
  bb <- st_bbox(c(xmin = cr$xmin,
                  xmax = cr$xmax,
                  ymin = cr$ymin,
                  ymax = cr$ymax),
                crs = 4326)
  retrieve_data(cr$city_name, cr$river_name, bb)
}
