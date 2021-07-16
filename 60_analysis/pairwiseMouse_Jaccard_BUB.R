#!/ usr/bin/Rscript

###
### Pairwise BUB and Jaccard index for pairwise mouse samples
###

### Within a batch (or could be two different batches, theoretically) a single mouse has produced two different tissue samples (e.g. tumor and blood).
### For each mouse, want to generate BUB and Jaccard index between the two different tissue samples

### Dependencies
suppressMessages(library(data.table))
library(MASS)
library(scales)
library(xlsx)
source("/home/exacloud/gscratch/CoussensLab/tcr_sequencing_tools/misc/utilityFxns.R")


### Commands
arguments <- commandArgs(trailingOnly=TRUE);

inputDir_v <- arguments[1];
batches_v <- arguments[2];
metaFile_v <- arguments[3];
tissues_v <- arguments[4];
compare_v <-arguments[5];
outDir_v <- arguments[6];
badSample_v <- arguments[7];
debug_v <- arguments[8];
log_v <- arguments[9];


### Handle other commands
batches_v <- unlist(strsplit(batches_v, split = ","))
tissues_v <- unlist(strsplit(tissues_v, split = ','))

### Get data
meta_dt <- fread(metaFile_v)
inputFiles_v <- list.files(inputDir_v)

if (length(batches_v) > 1){
  splitCol_v <- grep("batch|Batch", colnames(meta_dt), value = T)
  split1_v <- batches_v[1]; split2_v <- batches_v[2]
  base1_v <- unlist(strsplit(grep(split1_v, inputFiles_v, value = T)[1], split = "S[0-9]+"))
  base2_v <- unlist(strsplit(grep(split2_v, inputFiles_v, value = T)[1], split = "S[0-9]+"))
} else if (length(tissues_v) > 1){
  splitCol_v <- grep("tissue|Tissue", colnames(meta_dt), value = T)
  split1_v <- tissues_v[1];split2_v <- tissues_v[2]
  base1_v <- unlist(strsplit(inputFiles_v[1], split = "S[0-9]+")); base2_v <- base1_v
} else {
  stop("Either batch or treat must have 2 distinct entries.")
} # fi

### Get number of pairs
numPairs_v <- meta_dt[,.N] / 2

### Get column names
sampleCol_v <- grep("Sample|sample", colnames(meta_dt), value = T)
treatCol_v <- grep("Treat|treat", colnames(meta_dt), value = T)

### Empty variables
allID_v <- NULL; allS1_v <- NULL; allS2_v <- NULL; allReads1_v <- NULL; allReads2_v <- NULL; allJaccard_v <- NULL; allBUB_v <- NULL

### Iterate over pairs
for (i in 1:numPairs_v){
  ### Get 1st compare ID
  currID_v <- meta_dt[i,get(compare_v)]
  ### Get sample numbers
  currNum1_v <- meta_dt[get(compare_v) == currID_v &
                          get(splitCol_v) == split1_v, get(sampleCol_v)]
  currNum2_v <- meta_dt[get(compare_v) == currID_v &
                          get(splitCol_v) == split2_v, get(sampleCol_v)]
  ### Get data
  currData1_dt <- fread(file.path(inputDir_v, paste0(base1_v[1], "S", currNum1_v, base1_v[2])))
  currData2_dt <- fread(file.path(inputDir_v, paste0(base2_v[1], "S", currNum2_v, base1_v[2])))
  ### Create seq column
  currData1_dt$clone <- paste(currData1_dt$`V segments`, currData1_dt$clonalSequence, currData1_dt$`J segments`, sep = "_")
  currData2_dt$clone <- paste(currData2_dt$`V segments`, currData2_dt$clonalSequence, currData2_dt$`J segments`, sep = "_")
  ### Calculate Intersection and Union
  currInt_v <- intersect(currData1_dt$clone, currData2_dt$clone)
  currUnion_v <- union(currData1_dt$clone, currData2_dt$clone)
  currAll_v <- unique(c(currData1_dt$clone, currData2_dt$clone))
  currAbsent_v <- setdiff(currAll_v, currUnion_v)
  currJaccard_v <- length(currInt_v) / length(currUnion_v)
  ### Calculate BUB
  currNum_BUB <- length(currInt_v) + sqrt(length(currInt_v) * length(currAbsent_v))
  currDenom_BUB <- length(currUnion_v) + sqrt(length(currInt_v) * length(currAbsent_v))
  currBUB <- currNum_BUB / currDenom_BUB
  ### Create output columns
  allID_v <- c(allID_v, currID_v)
  allS1_v <- c(allS1_v, currNum1_v)
  allS2_v <- c(allS2_v, currNum2_v)
  allReads1_v <- c(allReads1_v, length(currData1_dt$clone))
  allReads2_v <- c(allReads2_v, length(currData2_dt$clone))
  allJaccard_v <- c(allJaccard_v, round(currJaccard_v, digits = 6))
  allBUB_v <- c(allBUB_v, round(currBUB, digits = 6))
}

output_dt <- data.table("ID" = allID_v,
                        "First" = allS1_v,
                        "FirstReads" = allReads1_v,
                        "Second" = allS2_v,
                        "SecondReads" = allReads2_v,
                        "Jaccard" = allJaccard_v,
                        "BUB" = allBUB_v)

colnames(output_dt) <- c("ID", split1_v, paste0(split1_v, "_Clones"), 
                         split2_v, paste0(split2_v, "_Clones"),
                         "Jaccard", "BUB")

if (length(batches_v) > 1){
  outName_v <- paste0(split1_v, "_vs_", split2_v, "_", tissues_v, "_pairwiseJaccard.txt")
} else {
  outName_v <- paste0(batches_v, "_", split1_v, "_vs_", split2_v, "_pairwiseJaccard.txt")
}

write.table(output_dt, file = file.path(outDir_v, outName_v), quote = F, row.names = F, sep = '\t')