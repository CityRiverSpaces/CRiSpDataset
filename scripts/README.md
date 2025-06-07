# Scripts

1. [`city_rivers_table.R`](./city_rivers_table.R): Clean the [Eurostat city population dataset](https://ec.europa.eu/eurostat/web/regions-and-cities) (see raw [dataset](../data/)) to identify urban areas with population above a certain threshold, identify main water streams in the urban areas (when present) and save output table to a CSV file (see output [dataset](../output/city_rivers.csv)).

2. [`download_input_datasets.R`](./download_input_datasets.R): Take the city river table (see point 1., dataset [here](../output/city_rivers.csv)), and for each city river retrieve input data required to carry out the corridor delineation and segmentation: street and rail networks, river centerline, digital elevation model (DEM).

3. [generate_corridor.R](./generate_corridor.R): Run the corridor delineation and segmentation, using the input data retrieved (see point 2.). The script carry out the delineations for a single city, taking the path to the input and output paths as command line arguments, e.g.:
```shell
Rscript generate_corridor.R /path/to/input/vector/data.gpkg /path/to/input/raster/dem.tif  /path/to/output/delineations.gpkg
```
Run for all cities via the [`generate_corridor.bash`](./generate_corridor.bash) shell script. NOTE: only the segments are actually saved as output, since the corridor can be easily obtained from the segments via unioning their geometries.

4. [`retrieve_features.R`](./retrieve_features.R): Using the corridor geometries, retrieve all the basic OSM features to calculate the metrics: streets and railways from all the hyerarchy levels, buildings, river geometries.

5. [`compute_metrics.R`](./compute_metrics.R): Estimate the metrics for all the city rivers, and save output to a CSV file (see output [dataset](../output/city_rivers_metrics.csv)).