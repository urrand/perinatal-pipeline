#!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base [options]
Setup of the perinatal pipeline.

Options:
  -h / -help / --help           Print usage.
"
  exit;
}

# arguments
code_dir=$(pwd)
echo $code_dir
logfile=$code_dir/setup_perinatal.log
rm -f $logfile

MIRTK_folder=$code_dir/build/MIRTK
DRAWEMDIR=$MIRTK_folder/Packages/DrawEM

echo "export ANTSPATH=<path/to/ANTs/bin>" >> $code_dir/parameters/path.sh

mkdir -p $DRAWEMDIR/atlases
cp -R $code_dir/perinatal/perinatal_atlases/* $DRAWEMDIR/atlases
mkdir -p $code_dir/parameters
cp -R $code_dir/perinatal/perinatal_parameters/* $code_dir/parameters
mkdir -p $DRAWEMDIR/pipelines
cp -R $code_dir/perinatal/perinatal_scripts/pipelines/* $DRAWEMDIR/pipelines
mkdir -p $code_dir/scripts
cp -R $code_dir/perinatal/perinatal_scripts/basic_scripts/* $code_dir/scripts
mkdir -p $DRAWEMDIR/scripts
cp -R $code_dir/perinatal/perinatal_scripts/scripts/* $DRAWEMDIR/scripts
