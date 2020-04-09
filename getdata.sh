## Get Seq data from NCBI SRA and run initial 

# Bioproject is PRJEB12126
# Bioproject description - Analysis of coronavirus and infected host-cell gene expression through RNA sequencing and ribosome profiling
#
# Stop on any error and print the command as they execute.
set -uex

# Get data from bioproject PRJEB12126 - run information
esearch -db sra -query PRJEB12126 | efetch -format runinfo > runinfo.csv

# Run ids
cat runinfo.csv | cut -f 1 -d , | grep ERR > ids

# Get fastq data for each SRR number in the bioproject
# Can use wonderdump sometimes instead of fastq-dump (the internal implementation of fastq-dump precludes it from working on Bash for Windows effectively)
# cat ids | wonderdump -X 10000 --split-files >> log.txt
cat ids | parallel fastq-dump -X 100000 --split-files >> log.txt

# Run fastqc on each file.
# FASTQC is for quality control tool for high throughput sequence data.
cat ids | parallel fastqc -q {}_1.fastq >> log.txt

# Integrate all fastqc files into one report
# multiqc $dir
multiqc /corona

#
#
#

## Get reference genome - MHV-A59, Accession - AF029248
efetch -db nuccore -id AF029248 -format fasta > AF029248.fa

# copy reference to genome
cp AF029248.fa genome.fa

# index reference genome file
bwa index genome.fa

#
#
#

## Align sequencing data to reference
# bwa mem for alignment - unpaired reads and convert sam to bam format and index bam file
# bwa mem genome.fa *.fastq > aligned.sam | samtools sort aligned.sam > aligned.bam |samtools index aligned.bam
cat ids | parallel "bwa mem genome.fa -1 {}_1.fastq > sam/{}.sam | samtools sort > bam/{}.bam | samtools index bam/{}.bam"

# Merge all bam files into one
samtools merge bam/merged.bam bam/*.bam

# Quickcheck for all bam files - seems ok
samtools quickcheck -v *.bam > bad_bams.fofn   && echo 'all ok' || echo 'some files failed check, see bad_bams.fofn'

#
#
###################################################

## Translatome analysis on the bam files using riborapter
# Adapted from https://riboraptor.readthedocs.io/en/latest/cmd-manual.html 

# Counting uniquely mapped reads
cat ids | parallel "riboraptor uniq-mapping-count --bam bam/{}.bam"

# Read length distribution
cat ids | parallel "riboraptor read-length-dist --bam bamnew/{}.bam | plot-read-dist --saveto images/{}.png"

# Further analyses following the R tutorial below.
# Link to the manual - https://www.bioconductor.org/packages/release/bioc/vignettes/RiboProfiling/inst/doc/RiboProfiling.pdf
