#!/usr/bin/sh

#SBATCH --partition             exacloud
#SBATCH --nodes                 1
#SBATCH --ntasks                20
#SBATCH --ntasks-per-core	1
#SBATCH --cpus-per-task         1
#SBATCH --mem-per-cpu           4000
#SBATCH --output                gliph-%A.%a.out
#SBATCH --error                 gliph-%A.%a.err
#SBATCH --array                 1-9

IN=$data/gliph/clones
OUT=$data/gliph/results
DB=/home/exacloud/lustre1/CompBio/users/hortowe/myApps/gliph/gliph/db/murineMammaryNaive.fa
LOG=$log/gliph/run
TODO=$data/gliph/todo/gliphToDo.txt

### Get specific file to run
CURRFILE=`awk -v line=$SLURM_ARRAY_TASK_ID '{if (NR == line) print $0}' $TODO`

echo "SLURM_JOBID: " $SLURM_JOBID
echo "SLURM_ARRAY_TASK_ID: " $SLURM_ARRAY_TASK_ID
echo "SLURM_ARRAY_JOB_ID: " $SLURM_ARRAY_JOB_ID
echo "Current file: " $CURRFILE

gliph-group-discovery.pl --tcr $IN/$CURRFILE --refdb=$DB