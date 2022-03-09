#!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base subject scan_age [options]
This script creates additional files for the dHCP structural pipeline.

Arguments:
  subject                       Subject ID

Options:
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -h / -help / --help           Print usage.
"
  exit;
}

process_image(){
  m=$1
  run fslmaths restore/$m/$subj.nii.gz -thr 0 restore/$m/$subj.nii.gz
  run N4 3 -i restore/$m/$subj.nii.gz -x masks/$subj-bet.nii.gz -o "[restore/$m/${subj}_restore.nii.gz,restore/$m/${subj}_bias.nii.gz]" -c "[50x50x50,0.001]" -s 2 -b "[100,3]" -t "[0.15,0.01,200]"
  run fslmaths restore/$m/${subj}_restore.nii.gz -mul masks/$subj.nii.gz restore/$m/${subj}_restore_brain.nii.gz
  run fslmaths restore/$m/${subj}_restore.nii.gz -mul masks/$subj-bet.nii.gz restore/$m/${subj}_restore_bet.nii.gz
}

deface_image(){
  m=$1
  run fslmaths restore/$m/$subj.nii.gz -mul masks/${subj}_mask_defaced.nii.gz restore/$m/${subj}_defaced.nii.gz
  run fslmaths restore/$m/${subj}_restore.nii.gz -mul masks/${subj}_mask_defaced.nii.gz restore/$m/${subj}_restore_defaced.nii.gz
}

hex2dec(){
  infile="${1:-/dev/stdin}"
  outfile=$2
  while read line; do
      for number in $line; do
          printf "%f " "$number"
      done
      echo
  done < $infile > $outfile
}

################ ARGUMENTS ################

[ $# -ge 2 ] || { usage; }
command=$@
subj=$1
age=$2
fetneo=$3
type=$4

datadir=`pwd`
threads=1

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $codedir/../../parameters/configuration.sh $fetneo

shift; shift; shift; shift
while [ $# -gt 0 ]; do
  case "$1" in
    -d|-data-dir)  shift; datadir=$1; ;;
    -t|-threads)  shift; threads=$1; ;; 
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done


echo "additional files for the dHCP pipeline
Subject:    $subj 
Directory:  $datadir 
Threads:    $threads

$BASH_SOURCE $command
----------------------------"

################ MAIN ################
cd $datadir

mkdir -p restore/$type

Tmasked=restore/$type/${subj}_restore_bet.nii.gz

# process T2 (bias correct, masked versions)
if [ ! -f $Tmasked ];then 
  cp N4/$subj.nii.gz restore/$type/$subj.nii.gz
  process_image $type
fi


if [ ! -f dofs/template-$age-$subj-n.dof.gz ];then
  run mirtk register $Tmasked $template_T2/template-$age.nii.gz -dofout dofs/template-$age-$subj-n.dof.gz -parin $registration_config_template -threads $threads -v 0
fi

if [ ! -f dofs/$subj-template-$age-r.dof.gz ];then
  run mirtk convert-dof dofs/$subj-template-$age-n.dof.gz dofs/$subj-template-$age-r.dof.gz -input-format mirtk -output-format rigid
fi

if [ ! -f dofs/template-$age-$subj-n.dof.gz ];then
  run mirtk invert-dof dofs/$subj-template-$age-n.dof.gz dofs/template-$age-$subj-i.dof.gz
  run mirtk register $template_T2/template-$age.nii.gz $Tmasked -dofin dofs/template-$age-$subj-i.dof.gz -dofout dofs/template-$age-$subj-n.dof.gz -parin $registration_config_template -threads $threads -v 0
  run rm dofs/template-$age-$subj-i.dof.gz 
fi
