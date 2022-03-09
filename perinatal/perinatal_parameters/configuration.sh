#!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base subject age [options]
This script runs the dHCP surface pipeline.

Arguments:
  subject                       Subject ID
  fetneo			0/1 flag for fetal/neonatal acquisition

Options:
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -t / -threads  <number>       Number of threads (CPU cores) allowed for the registration to run in parallel (default: 1)
  -h / -help / --help           Print usage.
"
  exit;
}

[ $# -ge 1 ] || { usage; }
command=$@
fetneo=$1

# local directories
export parameters_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export code_dir=$parameters_dir/..

# setup path from installation
[ ! -f $parameters_dir/path.sh ] || . $parameters_dir/path.sh

# cortical structures of labels file
export cortical_structures=`cat $DRAWEMDIR/parameters/cortical.csv`

# lookup table used with the wb_command to load labels
export LUT=$DRAWEMDIR/parameters/segAllLut.txt

# tissue labels of tissue-labels file
export CSF_label=1
export CGM_label=2
export WM_label=3
export BG_label=4

# MNI T1, mask and warps
export MNI_T1=$code_dir/atlases/MNI/MNI152_T1_1mm.nii.gz
export MNI_mask=$code_dir/atlases/MNI/MNI152_T1_1mm_facemask.nii.gz
export MNI_dofs=$code_dir/atlases/neonatal/dofs-MNI

if [ $fetneo -eq 0 ];
then
# Average space atlas name, T2 and warps
export template_name="fetal"
export template_T2=$code_dir/atlases/$template_name/T2
export template_mask=$code_dir/atlases/$template_name/mask
export template_min_age=21
export template_max_age=38
else
# Average space atlas name, T2 and warps
export template_name="neonatal"
export template_T1=$code_dir/atlases/$template_name/T1
export template_T2=$code_dir/atlases/$template_name/T2
export template_mask=$code_dir/atlases/$template_name/mask
export template_dofs=$code_dir/atlases/$template_name/dofs
export template_min_age=28
export template_max_age=44
fi

# registration parameters
export registration_config=$parameters_dir/ireg-structural.cfg
export registration_config_template=$parameters_dir/ireg.cfg

# surface reconstuction parameters
export surface_recon_config=$parameters_dir/recon-neonatal-cortex.cfg

# log function
run()
{
  echo "$@"
  "$@"
  if [ ! $? -eq 0 ]; then
    echo "$@ : failed"
    exit 1
  fi
}

# make run function global
typeset -fx run
