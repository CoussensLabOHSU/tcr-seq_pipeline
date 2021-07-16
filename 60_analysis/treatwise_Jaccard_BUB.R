#!/ usr/bin/Rscript

###
### Pairwise BUB and Jaccard index for pairwise mouse samples
###

### Want to compare clones between samples for each treatment

#############
### SETUP ###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#############

suppressMessages(library(data.table))
library(optparse)
library(MASS)
library(scales)
library(xlsx)
source("~/stable_repos_11_17/WesPersonal/utilityFxns.R")

#################
### ARGUMENTS ###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#################

### Make list of options
optlist <- list(
  make_option(
    c("-i", "--inputDir"),
    type = "character",
    help = "Input directory for normalized clone files for entire batch (or first batch, if only using one)"
  ),
  make_option(
    c("-b", "--batches"),
    type = "character",
    help = "Name of batch prefixes. If two, comma-separated, no spaces."
  ),
  make_option(
    c("-m", "--meta"),
    type = "character",
    help = "Metadata file containing treatment designations at a minimum. Require: Sample | Treatment | Mouse/Animal | Tissue (optional)"
  ),
  make_option(
    c("-f", "--freq"),
    type = "character",
    help = "Name of the clonal frequency group division that should be used for comparison. If blank, will calculate on full repertoire."
  ),
  make_option(
    c("-o", "--outDir"),
    type = "character",
    help = "file path to directory for writing output files"
  ),
  make_option(
    c("-b", "--badSamples"),
    type = "character",
    help = "Comma-separated, no space list of samples that should be removed"
  ),
  make_option(
    c("-d", "--debug"),
    type = "logical",
    default = FALSE,
    help = "Logical. TRUE - print session info and extra output to help with debugging. Also do not write output (tables and images). FALSE - normal output and write output files (tables and images)."
  ),
  make_option(
    c("-l", "--log"),
    type = "logical",
    default = FALSE,
    help = "Logical. TRUE - output session info. FALSE - do not output session info. If debug is TRUE and log is FALSE, then session info will be printed to STDOUT. If neither are set, no output."
  )
)

### Parse commandline
p <- OptionParser(usage = "%prog -i inputDir -b batches -m meta -t tissue -c compare -o outDir -b badSamples -d debug -l log",
                  option_list = optlist)
args <- parse_args(p)
opt <- args$options

### Commands
inputFile_v <- args$inputFile
batches_v <- args$batches
metaFile_v <- args$meta
freq_v <- args$freq
outDir_v <- args$outDir
badSample_v <- args$badSamples
debug_v <- args$debug
log_v <- args$log

#inputFile_v <- "~/Desktop/OHSU/tcr_spike/data/LIB170920LC/forPaper/oldNorm_noCollapse/freqGroups/LIB170920LC_full_clones.txt"
#batches_v <- "LIB170920LC"
#metaFile_v <- "~/Desktop/OHSU/tcr_spike/data/LIB170920LC/meta/LIB170920LC_noPcrMeta.txt"
#freq_v <- "Hyperexpanded"
#outDir_v <- "~/Desktop/OHSU/tcr_spike/data/LIB170920LC/forPaper/oldNorm_noCollapse/treatBUB/"
#badSample_v <- "8"
#debug_v <- F
#log_v <- F

##################
### PREPROCESS ###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##################

### Print commands
if (log_v){
  returnSessionInfo(args_lsv = args, out_dir_v = outDir_v)
} else {
  if (debug_v){
    returnSessionInfo(args_lsv = args)
  } # fi
} # fi

### Get data
meta_dt <- fread(metaFile_v)
inputData_dt <- fread(inputFile_v)

### Remove bad sample
badSample_v <- gsub("S", "", unlist(strsplit(badSample_v, split = ","))) #removes S from sample name
inputData_dt <- inputData_dt[!(Sample %in% paste0("S", badSample_v)), ]
meta_dt <- meta_dt[!(Sample %in% badSample_v),]

### Get column names from meta file
sampleCol_v <- grep("Sample|sample", colnames(meta_dt), value = T)
treatCol_v <- grep("Treat|treat", colnames(meta_dt), value = T)

### Make nucleotide clone
seqCol_v <- grep("clonalSequence|Clonal Sequence(s)", colnames(inputData_dt), value = T)
aaCol_v <- grep("aaSeqCDR3|AA. Seq. CDR3", colnames(inputData_dt), value = T)
vCol_v <- grep("^V", colnames(inputData_dt), value = T)
jCol_v <- grep("^J", colnames(inputData_dt), value = T)
inputData_dt$clone <- paste(inputData_dt[[vCol_v]], inputData_dt[[seqCol_v]], inputData_dt[[jCol_v]], sep = "_")
inputData_dt$aaClone <- paste(inputData_dt[[vCol_v]], inputData_dt[[aaCol_v]], inputData_dt[[jCol_v]], sep = "_")

### Get treatments
treats_v <- unique(meta_dt[[treatCol_v]])

### Subset for frequency, if specified
if (is.null(freq_v)){
  outName_v <- "allClones"
} else {
  inputData_dt <- inputData_dt[Div == freq_v,]
  outName_v <- paste0(freq_v, "_only")
}
################
### SORENSEN ###~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
################

### Calculate dissimilarity for each treatment
diss_mat <- matrix(nrow = length(treats_v), ncol = 3)
diss_mat[,1] <- treats_v

### For each type
cols_v <- c("clone", "aaClone")

for (i in 1:length(treats_v)){
  ## Get treat and subset data
  currTreat_v <- treats_v[i]
  currSub_dt <- inputData_dt[Treatment == currTreat_v,]
  ## Make table. Clones are columns, samples are rows. O if has clone, 1 if doesn't
  for (l in 1:length(cols_v)){
    ## Get clones and samples
    col_v <- cols_v[l]
    currClones_v <- unique(currSub_dt[[col_v]])
    currSamples_v <- paste0("S", meta_dt[get(treatCol_v) == currTreat_v, get(sampleCol_v)])
    ## Make binary matrix of clones and samples
    curr_mat <- matrix(nrow = length(currSamples_v), ncol = length(currClones_v))
    rownames(curr_mat) <- currSamples_v; colnames(curr_mat) <- currClones_v
    for (j in 1:length(currSamples_v)){
      currSample_v <- currSamples_v[j]
      for (k in 1:length(currClones_v)){
        currClone_v <- currClones_v[k]
        if (currClone_v %in% unlist(currSub_dt[Sample == currSample_v, mget(col_v)])){
          curr_mat[j,k] <- 1
        } else {
          curr_mat[j,k] <- 0
        } # fi
      } # for k
    } # for j
    ## Calculate dissimilarity - 1 is dissimilar, 0 is similar
    currDiss <- beta.multi(curr_mat, index.family = "sorensen")$beta.SOR
    ## Add to matrix
    diss_mat[i,(l+1)] <- currDiss
  } # for col_v
} # for i

diss_dt <- as.data.table(diss_mat)
colnames(diss_dt) <- c("Treat", "nt_Sorensen", "aa_Sorensen")
diss_dt[,("nt_Sorensen") := as.numeric(nt_Sorensen)]
diss_dt[,("aa_Sorensen") := as.numeric(aa_Sorensen)]



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