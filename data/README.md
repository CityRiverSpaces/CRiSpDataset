# Data

City population data have been taken from [Eurostat](https://ec.europa.eu/eurostat/web/main/home): https://ec.europa.eu/eurostat/web/regions-and-cities

The file [`estat_urb_cpop1_en.csv.zip`](./estat_urb_cpop1_en.csv.zip) contains population data as of 1 January of each year organized by age groups and sex, for cities and greater cities (dataset ID: `urb_cpop1`). The dataset can be retrieved via the following API call (executed on 2025-05-09):

```
https://ec.europa.eu/eurostat/api/dissemination/sdmx/3.0/data/dataflow/ESTAT/urb_cpop1/1.0?compress=false&format=csvdata&formatVersion=2.0&lang=en&labels=name
```
