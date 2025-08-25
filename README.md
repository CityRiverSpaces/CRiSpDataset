# CRiSp Dataset

This repository hosts material related to the creation of the City River Spaces (CRiSp) dataset.

## Setup

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
