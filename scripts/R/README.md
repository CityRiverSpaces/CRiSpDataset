# R Scripts

* [`01-city_rivers_table.R`](./01-city_rivers_table.R): Clean the [Eurostat city population dataset](https://ec.europa.eu/eurostat/web/regions-and-cities) (see raw [dataset](../data/) retrieved as part of this repository) to identify urban areas with population above a certain threshold. For each urban area, the main waterway is idenfified (when present) on the basis of Open Street Map (OSM) data.

* [`02-download_input_datasets.R`](./02-download_input_datasets.R): Take the City River table (see point 1., dataset [here](../output/city_rivers.csv)), and for each city river retrieve all the input data required to carry out the corridor delineation and segmentation: OSM datasets (street and rail networks, river centerline) and Copernicus 30m Digital Elevation Model (DEM).

* [`03-generate_corridor.R`](./03-generate_corridor.R): Run the corridor delineation and segmentation, using the input data retrieved (see point 2.). The script carries out the delineations for a single city, taking the path to the input and output paths as command line arguments, e.g.:
  ```shell
  Rscript 03-generate_corridor.R /path/to/input/vector/data.gpkg /path/to/input/raster/dem.tif  /path/to/output/delineations.gpkg
  ```
  Run for all cities via the [`03-generate_corridor.bash`](./generate_corridor.bash) shell script. NOTE: only the segments are actually saved as output, since the corridor can be easily obtained from the segments via unioning of their geometries.
