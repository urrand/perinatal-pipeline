#!/bin/bash
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

[ $# -ge 5 ] || { echo "usage: $(basename "$0") <subject> <age> <atlas_name> [<#jobs>]" 1>&2; exit 1; }
subj=$1
type=$2
atname=$3
age=$4
atlasname=$5
njobs=1
if [ $# -gt 5 ];then njobs=$6;fi

#registration
prefix=dofs/$subj-template-$age-n_
mkdir -p dofs

if [ ! -f ${prefix}1Warp.nii.gz ];then 
  
  fix_img=N4/$subj.nii.gz
  mov_img=$DRAWEMDIR/atlases/$atlasname/$type/template-$age.nii.gz
  if [ ! -f ${prefix}1Warp.nii.gz ];then
    sigma="4x2x1x0"
    shrink="8x4x2x1"
    iter="[500x250x100x10,1e-9,10]"
    metrics="MI[${fix_img},${mov_img},1,32,Random,1]"

    ${ANTSPATH}/antsRegistration -d 3 -i 0 -n BSpline -o ${prefix} --verbose 1 --float \
                        --winsorize-image-intensities [0.005,0.995] --use-histogram-matching 0 \
			-t Rigid[0.1] --metric ${metrics} -c ${iter} -s ${sigma} -f ${shrink} \
			-t Affine[0.1] --metric ${metrics} -c ${iter} -s ${sigma} -f ${shrink} \
			-t SyN[0.25,0,0] --metric ${metrics} -c ${iter} -s ${sigma} -f ${shrink}
  fi
fi

needtseg=0
for i in 0{1..9} {10..20};do
  atlas=${atname}_$i
  if [ ! -f dofs/$subj-${atname}_$i-n_1Warp.nii.gz ];then
    needtseg=1
    break
  fi
done

sdir=segmentations-data
if [ $needtseg -eq 1 -a ! -f $sdir/tissue-initial-segmentations/$subj.nii.gz ];then

    echo "creating $subj tissue priors"

    mkdir -p $sdir $sdir/template $sdir/tissue-posteriors $sdir/tissue-initial-segmentations || exit 1
    structures="csf gm wm outlier ventricles cerebstem dgm hwm lwm"
    for str in ${structures};do
    mkdir -p $sdir/template/$str $sdir/tissue-posteriors/$str || exit 1
    done

    strnum=0
    emsstructures=""
    emsposts=""

    for str in ${structures};do
    emsposts="$emsposts -saveprob $strnum $sdir/tissue-posteriors/$str/$subj.nii.gz"
    strnum=$(($strnum+1))

    strems=$sdir/template/$str/$subj.nii.gz
    ${ANTSPATH}/antsApplyTransforms -d 3 -i $DRAWEMDIR/atlases/$atlasname/atlas-9/structure$strnum/$age.nii.gz -r N4/$subj.nii.gz -o $strems -n BSpline -t [${prefix}1Warp.nii.gz] -t [${prefix}0GenericAffine.mat] --verbose 1 -f 0

    emsstructures="$emsstructures $strems"
    done

    mkdir -p logs
    run mirtk draw-em N4/$subj.nii.gz 9 $emsstructures $sdir/tissue-initial-segmentations/$subj.nii.gz -padding 0 -mrf $DRAWEMDIR/parameters/conn_tissues_ven_cstem_dgm_hwm_lwm.mrf -tissues 1 3 1 0 1 1 3 2 7 8 -hui -relaxtimes 2 $emsposts  1>logs/$subj-tissue-em 2>logs/$subj-tissue-em-err

    mkdir -p $sdir/gm-posteriors || exit 1
    run mirtk calculate $sdir/tissue-posteriors/gm/$subj.nii.gz -mul 100 -out $sdir/gm-posteriors/$subj.nii.gz 
fi
