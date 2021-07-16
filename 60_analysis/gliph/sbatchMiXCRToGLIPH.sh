#!/usr/bin/bash

#SBATCH --partition=exacloud
#SBATCH --nodes=1
#SBATCH --output=MiXCRToGLIPH-%j.txt
#SBATCH --error=MiXCRToGLIPH-%j.err
#SBATCH --verbose

CMD=$tool/gliph/MiXCRToGLIPH.R
IN=$data/normalization/normalized_clones/
OUT=$data/gliph/clones/
LOG=$data/condor_logs/gliph/convert

echo $IN
echo $OUT
echo $LOG
echo $CMD

srun $CMD -i $IN -o $OUT -m $META

mv MiXCRToGLIPH*.txt MiXCRToGLIPH*.err $LOG