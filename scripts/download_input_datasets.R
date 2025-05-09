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
  bind_rows(osm$osm_lines, osm$osm_multilines) |>
    filter(if_any(matches("name"), \(x) x == river_name)) |>
    # the query can return more features than actually intersecting the bb
    st_filter(st_as_sfc(bb), .predicate = st_intersects) |>
    st_geometry() |>
    st_union()
}

get_network <- function(aoi, force_download) {
  list(
    streets = get_osm_streets(aoi, force_download = force_download),
    railways = get_osm_railways(aoi, force_download = force_download)
  )
}

write_osm <- function(data, filepath, crs = NULL) {
  if (!is_path_valid(filepath)) return()
  for (name in names(data)) {
    if (!is.null(crs)) obj <- st_transform(data[[name]], crs)
    st_write(obj, filepath, layer = name, append = TRUE)
  }
}

write_dem <- function(data, filepath, crs = NULL) {
  if (!is_path_valid(filepath)) return()
  if (!is.null(crs)) obj <- project(data, crs(paste("EPSG", crs, sep = ":")))
  writeRaster(obj, filepath)
}

is_path_valid <- function(filepath) {
  if (file.exists(filepath)) {
    print(paste("File exists:", filepath, " - skipping it"))
    return(FALSE)
  } else {
    dir.create(dirname(filepath), showWarnings = FALSE)
    return(TRUE)
  }
}

# Load city rivers data frame
city_rivers <- read.csv(CITY_RIVERS_FILEPATH)
# Loop over rows of the data frame and retrieve data
for (n in seq_len(nrow(city_rivers))) {
  cr <- city_rivers[n, ]
  bb <- st_bbox(c(xmin = cr$xmin,
                  xmax = cr$xmax,
                  ymin = cr$ymin,
                  ymax = cr$ymax),
                crs = 4326)
  retrieve_data(cr$city_name, cr$river_name, bb)
}
