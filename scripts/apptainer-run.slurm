#!/bin/bash
#SBATCH --job-name="apptainer-run"
#SBATCH --partition=compute
#SBATCH --time=06:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu="3968MB"
#SBATCH --account=research-abe-ur

APPTAINER_IMAGE="crispdataset.sif"

apptainer run ${APPTAINER_IMAGE} $@ 
