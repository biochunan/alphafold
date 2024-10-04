#!/bin/zsh

# Aim: Predict structures using precomputed MSAs

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

# activate env
activate_conda_env() {
  conda init zsh >/dev/null 2>&1
  source $HOME/.zshrc
  conda activate $1
}

# Function to display usage
function usage() {
  echo "Usage: $(basename $0) [OPTIONS] --fasta <path> [--outdir <path>=$PWD] [--waitpid <pid>=<empty>] [--data <path>=/data/alphafold]"
  echo "  --fasta   <path>   : path to the HOST fasta file"
  echo "  --outdir  <path>   : path to the HOST output directory"
  echo "  --data    <path>   : path to the HOST data directory"
  echo "  --af2_root_dir      | -D : path to the AlphaFold2 root directory"
  echo "  --jackhmmer_n_cpu   | -J : number of CPUs for jackhmmer, default to 8"
  echo "  --hhblits_n_cpu     | -H : number of CPUs for hhblits, default to 4"
  echo "  --max_template_date | -T : maximum template date, default to today; AF2.3 training cutoff date is 2021-09-30"
  echo "  --waitpid <pid>    : PID to wait for"
  echo "  --help, -h         : display this help"
  echo ""
  echo "example usage:"
  echo "  $(basename $0) --fasta /mnt/data/alphafold/inputs/1akiA00.fasta \
        --outdir /host/path/to/out --data /host/path/to/data/alphafold --waitpid 1234"
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
jackhmmerNCpu=8  # default to 8 CPUs
hhblitsNCpu=4    # default to 4 CPUs

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

# assert FASTA is provided
if [ -z "$FASTA" ]; then
  echo "ERROR: FASTA is not provided"
  usage
fi

# ------------------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------------------
# activate conda environment
activate_conda_env alphafold

# Check if a PID is provided as the first command-line argument
if [ -n "$WAITPID" ]; then
  # Wait for the specified PID to complete
  echo waiting for PID $WAITPID to finish ...
  wait_for_pid $WAITPID
  echo PID $WAITPID completed
  echo
fi

# Run structure prediction using precomputed MSAs
python $afRootDir/run_alphafold.py \
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
  --use_precomputed_msas=true \
  --jackhmmer_n_cpu=$jackhmmerNCpu \
  --hhblits_n_cpu=$hhblitsNCpu \
  >$OUTDIR/run_struct_pred.log 2>&1
