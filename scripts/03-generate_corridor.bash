#!/bin/bash

VECTOR_DATA_DIR=./output/osm/
DEM_DATA_DIR=./output/dem
OUTPUT_DATA_DIR=./output/segments

R_CMD="Rscript" # Default R command

# Parse arguments
for arg in "$@"; do
  case $arg in
    --slurm) R_CMD="sbatch ./scripts/apptainer-run.slurm Rscript" ; shift ;;
    *) echo "Unknown arg $arg" ; exit 1 ;;
  esac
  shift
done

# Loop over existing input files, run delineations if output is missing
for VECTOR_DATA_PATH in ${VECTOR_DATA_DIR}/*.gpkg ; do
  FILENAME=`basename "${VECTOR_DATA_PATH}"`
  STEM="${FILENAME%.*}"
  DEM_DATA_PATH="${DEM_DATA_DIR}/${STEM}.tif"
  OUTPUT_DATA_PATH="${OUTPUT_DATA_DIR}/${STEM}.gpkg"
  if [ ! -f "${OUTPUT_DATA_PATH}" ] ; then
    ${R_CMD} \
      ./scripts/03-generate_corridor.R \
      "${VECTOR_DATA_PATH}" \
      "${DEM_DATA_PATH}" \
      "${OUTPUT_DATA_PATH}"
  fi
done

