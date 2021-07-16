#!/usr/bin/bash

#SBATCH --partition=exacloud
#SBATCH --nodes=1
#SBATCH --output=freqGroupToGLIPH-%j.txt
#SBATCH --error=freqGroupToGLIPH-%j.err
#SBATCH --verbose

CMD=$tool/gliph/freqGroupToGLIPH.R
IN=$data/freqGroups/treatSpecificClones/
OUT=$data/gliph/clones/
LOG=$data/condor_logs/gliph/convert

echo $IN
echo $OUT
echo $LOG
echo $CMD

srun $CMD -i $IN -o $OUT

mv freqGroupToGLIPH*.txt freqGroupToGLIPH*.err $LOG