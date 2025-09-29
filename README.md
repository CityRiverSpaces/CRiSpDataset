# CRiSp Dataset

This repository hosts material related to the creation of the City River Spaces (CRiSp) dataset.

## Setup

Clone and access this repository, which contains all the scripts required to build the dataset:

```shell
git clone https://github.com/CityRiverSpaces/CRiSpDataset.git
cd CRiSpDataset
```

Set up an environment with all the required dependencies. This can be achieved either via a [`local install`](#local-install) or by using [Docker](#docker) or [Apptainer](#apptainer) containers.

### Local install

R should be installed (see e.g. instructions on [CRAN](http://cran.r-project.org/)).

It is recommended to install the required dependencies in a project environment, which can be set up using [`renv`](https://rstudio.github.io/renv/). In the R terminal:

```r
# install.packages("renv")
renv::init(bare = TRUE)
```

When prompted for which files to use for dependency discovery, you can select `1` (DESCRIPTION file only). Restart the R terminal.
It is then easiest to install the project dependencies using [`devtools`](https://devtools.r-lib.org):

```r
install.packages("devtools")
devtools::install_deps()
```

### Docker

We also provide a Docker image that includes all the required dependencies. The image is published on the GitHub Container Registry (GHCR), see [the image page](https://github.com/CityRiverSpaces/CRiSpDataset/pkgs/container/crispdataset).

In order to start a container from the repository image:

- Docker [should be installed](https://docs.docker.com/get-started/get-docker/) and running.

- In a terminal window, run the following command to pull the image from the registry:

  ```shell
  docker pull ghcr.io/cityriverspaces/crispdataset:latest
  ```

- Start an interactive R session within the container with:

  ```shell
  docker run --rm -it ghcr.io/cityriverspaces/crispdataset:latest
  ```

  NOTE: the `--rm` option removes the container when terminated, the `-i` and `-t` options enable the interactive session.

### Apptainer

The published Docker image can also be used with Apptainer (e.g. on [DelftBlue](https://www.tudelft.nl/dhpc/system)):

- Pull the image from GHCR and convert it to SIF format:

  ```shell
  apptainer pull crispdataset.sif docker://ghcr.io/cityriverspaces/crispdataset:latest
  ```

- Start an interactive R session within the (Apptainer) container with:

  ```shell
  apptainer run crispdataset.sif
  ```

## Building the dataset

Ideally, a GitHub release of the repository should be published before starting to build a new version of the
dataset. Publishing the release, in fact, triggers the building of the container image, which is then
published with the same tag. Note that, for testing purposes, the image building process can also
be initiated manually (see "Run worflow" in
[the `Actions` tag](https://github.com/CityRiverSpaces/CRiSpDataset/actions/workflows/build_image.yml)).

Publishing a release of the GitHub repository also triggers a webhook that archives a snapshot of the repository on Zenodo.

(A new version of) the dataset is built via the following steps (more info on the scripts in the [`scripts`](./scripts/) folder):

- Clean the city population dataset from Eurostat (see the [`data`](./data/) folder). This step can be run on a
  local workstation using Docker as:

  ```shell
  docker run --rm -it ghcr.io/cityriverspaces/crispdataset:latest Rscript ./scripts/01-city_rivers_table.R
  ```

- Download all the required input datasets: [Open Street Map](www.openstreetmap.org) and [Copernicus DEM GLO-30](https://dataspace.copernicus.eu/explore-data/data-collections/copernicus-contributing-missions/collections-description/COP-DEM). Also this step can be run on a
  local workstation using Docker as:

  ```shell
  docker run --rm -it ghcr.io/cityriverspaces/crispdataset:latest Rscript ./scripts/02-download_input_datasets.R
  ```

- Generate the delineations for the cities. In order to run the delineations on [DelftBlue](https://doc.dhpc.tudelft.nl/delftblue/), copy the scripts and the retrieved input datasets to the cluster, e.g. to `/scratch`:

  ```shell
  scp -r ../CRiSpDataset delftblue:/scratch/fnattino/.
  ```

  Access DelftBlue, and pull the latest Apptainer image with all the required dependencies:

  ```shell
  ssh delftblue
  cd /scratch/fnattino/CRiSpDataset
  apptainer pull crispdataset.sif docker://ghcr.io/cityriverspaces/crispdataset:latest
  ```

  Submit all delineations to the queue:

  ```shell
  bash ./scripts/03-generate_corridor.bash --slurm
  ```

- Collect all delineation output in a single file:
  ```shell
  apptainer run crispdataset.sif Rscript ./scripts/04-collect-output.R
  ```

The file `crisp-dataset.gpkg` contains the new version of the dataset, and it can be released as a new version of the
["CRiSp Dataset" record in the "CityRiverSpaces" Community on Zenodo]().