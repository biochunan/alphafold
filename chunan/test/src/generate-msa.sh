#!/bin/zsh

BASE=$(realpath $(dirname $0))

zsh $BASE/run-af2.3.sh \
  --fasta_seq $BASE/../input/7a3o_0P.fasta \
  --name 7a3o_0P \
  --outdir $BASE/../out \
  --af2data /mnt/stuart/dataset/alphafold \
  --image_name chunan/alphafold2.3:dev \
  -msa \
  --dont_compress \
  --gpus 0 \
  --jackhmmer_n_cpu 8 \
  --hhblits_n_cpu 4