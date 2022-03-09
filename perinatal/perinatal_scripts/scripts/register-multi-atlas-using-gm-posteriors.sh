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

[ $# -ge 4 -a $# -le 5 ] || { echo "usage: $(basename "$0") <subject> <age> <#jobs>" 1>&2; exit 1; }
subj=$1
type=$2
atname=$3
age=$4
njobs=1
if [ $# -gt 4 ];then njobs=$5;fi

sdir=segmentations-data

scriptdir=$sdir/../../../scripts

mkdir -p dofs
# mkdir -p warps
atlas=${atname}
if [ ! -f $DRAWEMDIR/atlases/${atname}s/vent-posteriors-v3/$atlas.nii.gz ];then  
mkdir -p $DRAWEMDIR/atlases/${atname}s/vent-posteriors-v3
python $scriptdir/generateGM.py -i $DRAWEMDIR/atlases/${atname}s/tissues-v3/$atlas.nii.gz -o $DRAWEMDIR/atlases/${atname}s/vent-posteriors-v3/$atlas.nii.gz -t 5
fi
prefix=dofs/$subj-$atlas-n_
fix_img1=N4/$subj.nii.gz
mov_img1=$DRAWEMDIR/atlases/${atname}s/T2/$atlas.nii.gz
fix_img2=$sdir/gm-posteriors/$subj.nii.gz
mov_img2=$DRAWEMDIR/atlases/${atname}s/gm-posteriors-v3/$atlas.nii.gz
fix_img3=$sdir/tissue-posteriors/ventricles/$subj.nii.gz
mov_img3=$DRAWEMDIR/atlases/${atname}s/vent-posteriors-v3/$atlas.nii.gz
fix_mask=$sdir/../segmentations/${subj}_brain_mask.nii.gz
mov_mask=$DRAWEMDIR/atlases/${atname}s/mask/$atlas.nii.gz
if [ ! -f $DRAWEMDIR/atlases/${atname}s/mask/$atlas.nii.gz ];then
  mkdir -p $DRAWEMDIR/atlases/${atname}s/mask
  python $scriptdir/threshold_mask.py -i $DRAWEMDIR/atlases/${atname}s/T2/$atlas.nii.gz -o $mov_mask
fi
if [ ! -f ${prefix}1Warp.nii.gz ];then
  sigma="4x2x1x0"
  shrink="8x4x2x1"
  iter="[500x250x100x10,1e-9,10]"
  metrics1="MI[${fix_img1},${mov_img1},0.34,32,None]"
  metrics2="MeanSquares[${fix_img2},${mov_img2},0.33,NA,None]"
  metrics3="MeanSquares[${fix_img3},${mov_img2},0.33,NA,None]"

  ${ANTSPATH}/antsRegistration -d 3 -i 0 -n BSpline -o ${prefix} --verbose 1 --float \
                        --winsorize-image-intensities [0.005,0.995] --use-histogram-matching 0 -x [$fix_mask,$mov_mask] \
			-t Rigid[0.1] --metric ${metrics1} --metric ${metrics2} --metric ${metrics3} -c ${iter} -s ${sigma} -f ${shrink} \
			-t Affine[0.1] --metric ${metrics1} --metric ${metrics2} --metric ${metrics3} -c ${iter} -s ${sigma} -f ${shrink} \
			-t SyN[0.25,0,0] --metric ${metrics1} --metric ${metrics2} --metric ${metrics3} -c ${iter} -s ${sigma} -f ${shrink}

fi

j=0
for i in 0{1..9} {10..20};do
  ${ANTSPATH}/antsApplyTransforms -d 3 -i $DRAWEMDIR/atlases/${atname}s/T2/${atlas}_${i}.nii.gz -r N4/$subj.nii.gz -o [dofs/$subj-${atlas}_${i}-n_1Warp.nii.gz,1] -n BSpline -t [$DRAWEMDIR/atlases/${atname}s/T2/reg_${atlas}_${i}${j}1Warp.nii.gz] -t [$DRAWEMDIR/atlases/${atname}s/T2/reg_${atlas}_${i}${j}0GenericAffine.mat] -t [dofs/$subj-$atlas-n_1Warp.nii.gz] -t [dofs/$subj-$atlas-n_0GenericAffine.mat] --verbose 1 -f 0
  let "j=j+1"
done

