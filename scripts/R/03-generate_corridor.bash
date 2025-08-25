#!/bin/bash

VECTOR_DATA_DIR=../output/osm/
DEM_DATA_DIR=../output/dem
OUTPUT_DATA_DIR=../output/segments

for VECTOR_DATA_PATH in ${VECTOR_DATA_DIR}/*.gpkg ; do
  FILENAME=`basename "${VECTOR_DATA_PATH}"`
  STEM="${FILENAME%.*}"
  DEM_DATA_PATH="${DEM_DATA_DIR}/${STEM}.tif"
  OUTPUT_DATA_PATH="${OUTPUT_DATA_DIR}/${STEM}.gpkg"
  if [ ! -f "${OUTPUT_DATA_PATH}" ] ; then
    Rscript generate_corridor.R "${VECTOR_DATA_PATH}" "${DEM_DATA_PATH}" "${OUTPUT_DATA_PATH}"
  fi
done

