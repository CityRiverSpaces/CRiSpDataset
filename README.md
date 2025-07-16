# CRiSp Dataset

This repository hosts material related to the creation of the City River Spaces (CRiSp) dataset.

## Setup

### Local install

R should be installed (see e.g. instructions on [CRAN](http://cran.r-project.org/)).
Create a R environment with all the required packages by running:

```shell
# install.packages("renv")
renv::init(bare = TRUE)
renv::restore()
```

### Docker

Depencencies are installed in a Docker image that is published to the GitHub Container Registry
(GHCR), see [the image page](https://github.com/CityRiverSpaces/CRiSpDataset/pkgs/container/crispdataset).

In order to start a container based on the provided image:

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
