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

- Authenticate to GHCR using the Docker command line tool. You should first generate a Personal Access
  Token from the GitHub web interface (see instructions [here](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)), then run in a terminal window:

  ```shell
  docker login ghcr.io -u <YOUR_GITHUB_USERNAME>
  ```

  and provide the just-generated token when prompted for a password.

- Run the following command to ppull the image from the registry:

  ```shell
  docker pull ghcr.io/cityriverspaces/crispdataset:latest
  ```

- Start an interactive session in the R console within the container with:

  ```shell
  docker run --rm -it ghcr.io/cityriverspaces/crispdataset:latest
  ```

  NOTE: the `--rm` option removes the container when terminated, the `-i` and `-t` options enable the interactive session.
