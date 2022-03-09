# Perinatal Pipeline 

![pipeline image](perinatal_pipeline.png)

### Developers

**Andrea Urru**: main author.

**Valentin Comte**: contributor.

## Running the perinatal pipeline on Ubuntu

To run the perinatal pipeline you will need to download and install the [dHCP pipeline](https://github.com/BioMedIA/dhcp-structural-pipeline). 

Once the dHCP pipeline has been installed, you will need to install [ANTs](http://stnava.github.io/ANTs/).

After these steps, you can clone this repository and then copy its content in the dhcp-structural-pipeline previously created. After running the setup_perinatal.sh script you will be able to run the pipeline using the following command line:

./perinatal-pipeline.sh <path/to/raw/images> <image type (T2/T1)> <path/to/demographics/csv/file> <fetneo flag (0 for fetal, 1 for neonatal)> <multisubject altas to use (ANDREAs/ALBERTs)>

The raw files should be in a directory named after their image type (T2/T1). For example, if the image type is T2, the script will look for the files in the folder <path/to/raw/images>/T2/.
