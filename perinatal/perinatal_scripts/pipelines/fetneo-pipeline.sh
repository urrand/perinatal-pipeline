#! /bin/bash
# ============================================================================
# Developing brain Region Annotation With Expectation-Maximization (Draw-EM)
#
# Copyright 2013-2016 Imperial College London
# Copyright 2013-2016 Andreas Schuh
# Copyright 2013-2016 Antonios Makropoulos
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================

usage()
{
  base=$(basename "$0")
  echo "usage: $base subject_T2.nii.gz scan_age [options]
This script runs the neonatal segmentation pipeline of Draw-EM.

Arguments:
  subject_T2.nii.gz             Nifti Image: The T2 image of the subject to be segmented.
  scan_age                      Number: Subject age in weeks. This is used to select the appropriate template for the initial registration. 
			        If the age is <28w or >44w, it will be set to 28w or 44w respectively.
Options:
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -c / -cleanup  <0/1>          Whether cleanup of temporary files is required (default: 1)
  -p / -save-posteriors  <0/1>  Whether the structures' posteriors are required (default: 0)
  -atlas  <atlasname>           Atlas used for the tissue priors (default: non-rigid-v2)
  -t / -threads  <number>       Number of threads (CPU cores) allowed for the registration to run in parallel (default: 1)
  -v / -verbose  <0/1>          Whether the script progress is reported (default: 1)
  -h / -help / --help           Print usage.
"
  exit;
}



if [ -n "$DRAWEMDIR" ]; then
  [ -d "$DRAWEMDIR" ] || { echo "DRAWEMDIR environment variable invalid!" 1>&2; exit 1; }
else
  export DRAWEMDIR="$(cd "$(dirname "$BASH_SOURCE")"/.. && pwd)"
fi

[ $# -ge 5 ] || { usage; }
T=$1
type=$2
age=$3
fetneo=$4
atname=$5

[ -f "$T" ] || { echo "The image provided as argument does not exist!" >&2; exit 1; }
subj=`basename $T  |sed -e 's:.nii.gz::g' |sed -e 's:.nii::g'`
age=`printf "%.*f\n" 0 $age` #round
[ $age -lt $template_max_age ] || { age=$template_max_age; }
[ $age -gt $template_min_age ] || { age=$template_min_age; }

cleanup=1 # whether to delete temporary files once done
datadir=`pwd`
posteriors=0   # whether to output posterior probability maps
threads=1
verbose=1
command="$@"

shift; shift; shift; shift; shift
while [ $# -gt 0 ]; do
  case "$1" in
    -c|-cleanup)  shift; cleanup=$1; ;;
    -d|-data-dir)  shift; datadir=$1; ;;
    -p|-save-posteriors) shift; posteriors=$1; ;;
    -atlas)  shift; atlasname=$1; ;; 
    -t|-threads)  shift; threads=$1; ;; 
    -v|-verbose)  shift; verbose=$1; ;; 
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done

echo "Atlas used: "$atlasname

version=`git -C "$DRAWEMDIR" branch | grep \* | cut -d ' ' -f2`
gitversion=`git -C "$DRAWEMDIR" rev-parse HEAD`

[ $verbose -le 0 ] || { echo "DrawEM multi atlas  $version (branch version: $gitversion)
Subject:    $subj 
Age:        $age
Directory:  $datadir 
Posteriors: $posteriors 
Cleanup:    $cleanup 
Threads:    $threads

$BASH_SOURCE $command
----------------------------"; }

mkdir -p logs || exit 1

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

run_script()
{
  echo "$@"
  "$DRAWEMDIR/scripts/$@"
  if [ ! $? -eq 0 ]; then
    echo "$DRAWEMDIR/scripts/$@ : failed"
    exit 1
  fi
}

rm -f logs/$subj logs/$subj-err
run_script preprocess.sh     $subj $type $fetneo $age
# phase 1 tissue segmentation
run_script tissue-priors.sh     $subj $type $atname $age $atlasname $threads
# registration using gm posterior + image
run_script register-multi-atlas-using-gm-posteriors.sh $subj $type $atname $age $threads
# structural segmentation
run_script labels-multi-atlas.sh   $subj $type $atname
run_script segmentation.sh      $subj
# post-processing
run_script separate-hemispheres.sh  $subj
run_script correct-segmentation.sh  $subj
run_script postprocess.sh       $subj

# if probability maps are required
[ "$posteriors" == "0" -o "$posteriors" == "no" -o "$posteriors" == "false" ] || run_script postprocess-pmaps.sh $subj

# cleanup
if [ "$cleanup" == "1" -o "$cleanup" == "yes" -o "$cleanup" == "true" ] && [ -f "segmentations/${subj}_labels.nii.gz" ];then
  run_script clear-data.sh $subj
  rm -f logs/$subj logs/$subj-err
  rmdir logs 2> /dev/null # may fail if other log files exist
fi

exit 0
