#!/bin/zsh

# Aim: Create MSAs
# Input:
#   - FASTA  : path to the fasta file
#   - OUTDIR : path to the output directory (default: $PWD)
#   - DATA   : path to the data directory (default: /mnt/data/alphafold)
#   - WAITPID: PID to wait for

# ------------------------------------------------------------------------------
# FUNCTION
# ------------------------------------------------------------------------------
# Function to wait for a process to complete
wait_for_pid() {
  local pid=$1
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1
  done
}

# Function to display usage
function usage() {
  echo "Usage: $(basename $0) [OPTIONS] --fasta <path> [--outdir <path>=$PWD] [--waitpid <pid>=<empty>] [--data <path>=/data/alphafold]"
  echo "  --fasta   <path>   : path to the fasta file"
  echo "  --outdir  <path>   : path to the output directory"
  echo "  --waitpid <pid>    : PID to wait for"
  echo "  --data    <path>   : path to the data directory"
  echo "  --af2_root_dir      | -D : path to the AlphaFold2 root directory"
  echo "  --jackhmmer_n_cpu   | -J : number of CPUs for jackhmmer, default to 8"
  echo "  --hhblits_n_cpu     | -H : number of CPUs for hhblits, default to 4"
  echo "  --max_template_date | -T : maximum template date, default to today; AF2.3 training cutoff date is 2021-09-30"
  echo "  --help, -h         : display this help"
  exit 1
}

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------
BASE=/home/vscode/alphafold/
TODAY=$(date +%Y-%m-%d) # 2021-07-01

# ------------------------------------------------------------------------------
# INPUT
# ------------------------------------------------------------------------------
# DEFAULT VALUES
OUTDIR=$PWD
WAITPID=""
DATA=/mnt/data/alphafold
afRootDir=/home/vscode/alphafold
MAX_TEMPLATE_DATE=$TODAY  # default to today, AF2.3 training cutoff date is 2021-09-30
jackhmmerNCpu=8  # default to max number of CPUs
hhblitsNCpu=4    # default to max number of CPUs

# Parse command line options
while [[ $# -gt 1 ]]; do
  key="$1"
  case $key in
  --fasta)
    FASTA="$2"
    shift 2
    ;;
  --outdir)
    OUTDIR="$2"
    shift 2
    ;;
  --waitpid)
    WAITPID="$2"
    shift 2
    ;;
  --data)
    DATA="$2"
    shift 2
    ;;
  --af2_root_dir | -D)
    afRootDir="$2"
    shift 2
    ;;
  --jackhmmer_n_cpu | -J)
    jackhmmerNCpu="$2"
    shift 2
    ;;
  --hhblits_n_cpu | -H)
    hhblitsNCpu="$2"
    shift 2
    ;;
  --max_template_date | -T)
    MAX_TEMPLATE_DATE="$2"
    shift 2
    ;;
  --help | -h)
    usage
    shift # past argument
    exit 1
    ;;
  *)
    echo "Illegal option: $key"
    usage
    exit 1
    ;;
  esac
done

# Check if FASTA is provided
if [ -z "$FASTA" ]; then
  echo "ERROR: FASTA is not provided"
  usage
fi

echo "----------------------------------------"
echo "Inputs:"
echo "  FASTA  : $FASTA"
echo "  OUTDIR : $OUTDIR"
echo "  WAITPID: $WAITPID"
echo "  DATA   : $DATA"
echo "  MAX_TEMPLATE_DATE: $MAX_TEMPLATE_DATE"
echo "----------------------------------------"
echo

# ------------------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------------------
# activate conda environment
conda init zsh >/dev/null 2>&1
source $HOME/.zshrc
conda activate alphafold

# Check if a PID is provided as the first command-line argument
if [ -n "$WAITPID" ]; then
  # Wait for the specified PID to complete
  echo waiting for PID $WAITPID to finish ...
  wait_for_pid $WAITPID
  echo PID $WAITPID completed
  echo
fi

# Run MSA script
mkdir -p $OUTDIR && pushd $OUTDIR
python $afRootDir/run_alphafold_msa.py \
  --fasta_paths=$FASTA \
  --model_preset=multimer \
  --max_template_date=${MAX_TEMPLATE_DATE} \
  --output_dir=$OUTDIR \
  --data_dir=$DATA \
  --bfd_database_path=$DATA/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
  --uniref30_database_path=$DATA/uniref30/UniRef30_2021_03 \
  --uniref90_database_path=$DATA/uniref90/uniref90.fasta \
  --mgnify_database_path=$DATA/mgnify/mgy_clusters_2022_05.fa \
  --template_mmcif_dir=$DATA/pdb_mmcif/mmcif_files \
  --obsolete_pdbs_path=$DATA/pdb_mmcif/obsolete.dat \
  --pdb_seqres_database_path=$DATA/pdb_seqres/pdb_seqres.txt \
  --uniprot_database_path=$DATA/uniprot/uniprot.fasta \
  --use_gpu_relax=true \
  --jackhmmer_n_cpu=$jackhmmerNCpu \
  --hhblits_n_cpu=$hhblitsNCpu \
  >$OUTDIR/run_msa.log 2>&1
