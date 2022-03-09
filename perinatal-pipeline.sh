#!/bin/bash

source /home/u153881/py3.6/bin/activate

usage()
{
  base=$(basename "$0")
  echo "usage: $base <subject_dir> <session_ID> <scan_age> -T2 <subject_T2.nii.gz> [-T1 <subject_T1.nii.gz>] [options]
This script runs the perinatal structural pipeline.

Arguments:
  subject_dir 			Subject directory.
  type 				T2 or T1 (there has to be a subfolder in the subject directory with the type name)
  gaFile			File containing age information
  fetneo			Binary variable representing fetal (0) or neonatal (1) data
  atname			multisubject atlas to be used (look in the atlases folder)

Options:
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -t / -threads  <number>       Number of threads (CPU cores) used (default: 1)
  -no-reorient                  The images will not be reoriented before processing (using the FSL fslreorient2std command) (default: False) 
  -no-cleanup                   The intermediate files produced (workdir directory) will not be deleted (default: False) 
  -h / -help / --help           Print usage.
"
  exit 1
}

# log function for completion
runpipeline()
{
  pipeline=$1
  shift
  log=$logdir/$subj.$pipeline.log
  err=$logdir/$subj.$pipeline.err
  echo "running $pipeline pipeline"
  echo "$@"
  "$@" >$log 2>$err
  if [ ! $? -eq 0 ]; then
    echo "Pipeline failed: see log files $log $err for details"
    exit 1
  fi
  echo "-----------------------"
}


################ Arguments ################

[ $# -ge 5 ] || { usage; }
command=$@
subject_dir=$1
type=$2
gaFile=$3
fetneo=$4
atname=$5

datadir=`pwd`
threads=1
minimal=1
noreorient=0
cleanup=0

shift; shift; shift; shift; shift;
while [ $# -gt 0 ]; do
  case "$1" in
    -t|-threads)  shift; threads=$1; ;;
    -additional)  minimal=0; ;;
    -no-reorient) noreorient=1; ;;
    -no-cleanup) cleanup=0; ;;
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done

#dataLine=1
if [ -f "$subject_dir" ]; then
files=$subject_dir
subject_dir="$(dirname $subject_dir)"
subject_dir="$(dirname $subject_dir)"
echo $subject_dir
else
files=`ls $subject_dir/$type/*.nii.gz`
fi
for eachfile in $files
do

	###############################################
	# READ GA Table
	###############################################
	# use -A option declares associative array
	declare -A ga

	INPUT=$gaFile
	OLDIFS=$IFS
	IFS=,	
	[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
	while read id_data fetal_gw neo_gw
	do
	if [ $fetneo == 0 ];
	then
	ga[$id_data]=$fetal_gw
	else
	ga[$id_data]=$neo_gw
	fi
	done < $INPUT
	IFS=$OLDIFS
	###############################################
	
	if [ "$type" == "T1" ] ; 
	then 
	T1=$eachfile
	else
	T2=$eachfile
	fi
	
	filename="$(basename -- $eachfile)"
	prefix="final_reconstructed_"
	filename=${filename#"$prefix"}	

	subj=${filename%".nii.gz"} #$subjectID-$sessionID #impact ${eachfile:29:7} #fetal ${eachfile:47:7} #neonatal ${eachfile:40:6}

	if [ $fetneo == 0 ];
	then
	prefix="fet"
	else
	prefix="neo"
	fi

	subjID=${subj#"$prefix"}
	index=$((10#$subjID)) 

	sessionID=$prefix

	subj=$sessionID-$subjID

	if [ "$type" == "T1" ] ; 
	then 
	T2=$subject_dir/T2/$subj
	else
	T1=$subject_dir/T1/$subj
	fi
	
	age=`echo ${ga[$index]} | tr '.' ','`
	echo "Age: " $age
	
	#let "dataLine=dataLine+1"

	# check whether the different tools are set and load parameters
	codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	. $codedir/parameters/configuration.sh $fetneo

	scriptdir=$codedir/scripts

	roundedAge=`printf "%.*f\n" 0 $age` #round
	[ $roundedAge -lt $template_max_age ] || { roundedAge=$template_max_age; }
	[ $roundedAge -gt $template_min_age ] || { roundedAge=$template_min_age; }

	# infodir=$datadir/info 
	logdir=$datadir/logs
	workdir=$datadir/workdir/$subj
	# mkdir -p $infodir
	mkdir -p $workdir $logdir

	for modality in T1 T2;do 
	  mf=${!modality};
	  if [ "$mf" == "-" -o "$mf" == "" ]; then continue; fi
	  mkdir -p $workdir/$modality
	  newf=$workdir/$modality/$subj.nii.gz
	  if [ $noreorient -eq 1 ];then
	    cp $mf $newf
	  else
	    echo "Reorienting..."
	    fslreorient2std $mf $newf
	  fi
	  eval "$modality=$newf"
	done

	echo "T1:" $T1
	echo "T2:" $T2

	if [ -f $T2 ]; 
	then
		echo "T2 file exists and will be used for segmentation"
		type1=T2
		T=$T2
	else	
		echo "T2 file does not exist, T1 will be used for segmentation and surface extraction"
		type1=T1		
		T=$T1
	fi

	# segmentation
	runpipeline segmentation $scriptdir/segmentation/pipeline.sh $T $type1 $subj $roundedAge $fetneo $atname -d $workdir -t $threads

	runpipeline additional $scriptdir/misc/pipeline.sh $subj $roundedAge $fetneo $type1 -d $workdir -t $threads

	# surface extraction
	runpipeline surface $scriptdir/surface/pipeline.sh $subj -d $workdir -t $threads

	# clean-up
	if [ $cleanup -eq 1 ];then
	  runpipeline cleanup rm -r $workdir
	fi

	echo "dHCP pipeline completed!"
done


