#!/bin/zsh

# Aim: Run AF2.3 on a given AbDb id

##############################################################################
# FUNCTION                                                                   #
##############################################################################
scriptName=$(basename $0)
usage() {
  echo "Usage: $scriptName [options]"
  echo "Options:"
  echo "  --fasta_seq | -f: Path to the fasta sequence file"
  echo "  --name      | -n: Job name, msa & struct are written to <outdir>/<name>"
  echo "  --outdir    | -o: Output directory"
  echo "  --af2data   | -D: Path to the alphafold required seqeunce data"
  echo "  --generate_msa_only      | -msa: Generate MSA only"
  echo "  --predict_structure_only | -pst: Predict structure only"
  echo "  --level         : Minimum log level (DEBUG, INFO, WARNING, ERROR)"
  # add example
  echo "Example:"
  echo "zsh src/run-af2.3.sh \\
    -f ./out/seqres---epitope-group---test_set/1oak_0P.seqres.fasta \\
    -n 1oak_0P \\
    -o ./out/af2.3-output"
  exit 1
}

# Function to print timestamp YYYYMMDD-HHMMSS
print_timestamp() {
  date +"%Y%m%d-%H%M%S"  # e.g. 20240318-085729
}

# Define severity levels
declare -A severity_levels
severity_levels=(
  [DEBUG]=10
  [INFO]=20
  [WARNING]=30
  [ERROR]=40
)

# Print message with time only if level is greater than INFO, to stderr
MINLOGLEVEL="INFO"
print_msg() {
  local message="$1"
  local level=${2:-INFO}

  if [[ ${severity_levels[$level]} -ge ${severity_levels[$MINLOGLEVEL]} ]]; then
    >&2 echo -e "[$level] $(print_timestamp): $message"        # showing messages
  else
    echo -e "[$level] $(print_timestamp): $message" >&2  # NOT showing messages
  fi
}

# read input (non-silent)
read_input() {
  echo -n "$1"
  read $2
}

# read input silently
read_input_silent() {
  echo -n "$1"
  read -s $2
  echo
}

ask_reset() {
  local varName=${1:-"it"}
  # do you want to reset?
  while true; do
    read_input "Do you want to reset ${varName}? [y/n]: " reset
    case $reset in
      [Yy]* )
        return 1
        break
        ;;
      [Nn]* )
        return 0
        break
        ;;
      * )
        echo "Please answer yes or no."
        ;;
    esac
  done
}

# a function to get file name without the extension
getStemName() {
  local file=$1
  baseName=$(basename $file)
  echo ${baseName%.*}
}

##############################################################################
# CONFIG                                                                     #
##############################################################################
BASE=$(dirname $(realpath $0))
# NOTE: change this to the path where the alphafold data is stored
AFDATA=/mnt/bob/shared/alphafold
IMAGE_NAME="$USER/alphafold2.3:base"

##############################################################################
# INPUT                                                                      #
##############################################################################
GENERATE_MSA_ONLY=false
PREDICT_STRUCTURE_ONLY=false
COMPRESS=true
GPUDEVICE="all"
JACKHMMER_N_CPU=8  # $(nproc)
HHBLITS_N_CPU=4    # $(nproc)
# Parse command line options
while [[ $# -gt 0 ]]
do
  key="$1"
  case $key in
    --fasta_seq | -f)
      fastaPath="$2"
      shift 2;; # fasta sequence file
    --name | -n)
      name="$2"
      shift 2;; # job name e.g. '1aok_0P'
    --outdir | -o)
      outDir="$2"
      shift 2;; # parent folder, i.e. msa & struct are written to $outDir/$name
    --af2data | -D)
      AFDATA="$2"
      shift 2;; # path to the alphafold data
    --jackhmmer_n_cpu)
      JACKHMMER_N_CPU="$2"
      shift 2;; # number of cpu for jackhmmer
    --hhblits_n_cpu)
      HHBLITS_N_CPU="$2"
      shift 2;; # number of cpu for hhblits
    --image_name | -I)
      IMAGE_NAME="$2"
      shift 2;; # docker image name
    --generate_msa_only | -msa)
      GENERATE_MSA_ONLY=true
      shift;;
    --predict_structure_only | -pst)
      PREDICT_STRUCTURE_ONLY=true
      shift;; # pst stands for "p"redict "st"ructure
    --dont_compress)
      COMPRESS=false
      shift;; # compress the output folder
    --gpus)
      GPUDEVICE="$2"  # default to all, accept e.g. "0,1", "1", "all"
      shift 2;; # ignore
    --level)
      MINLOGLEVEL="$2"
      shift 2;; # past argument and value
    --help | -h)
      usage
      shift # past argument
      exit 1;;
    *)
      echo "Illegal option: $key"
      usage
      exit 1;;
  esac
done

# assert fasta_seq is provided and exists
[[ -z $fastaPath ]] && { print_msg "Fasta sequence is required" "ERROR"; usage; }
[[ ! -f $fastaPath ]] && { print_msg "Fasta sequence file does not exist" "ERROR"; usage; }
fastaPath=$(realpath $fastaPath)

# if name not provided, use the stem name of the fasta file
[[ -z $name ]] && name=$(getStemName $fastaPath)

# if outdir not provided, use the current directory
[[ -z $outDir ]] && outDir=$(pwd)
outDir=$(realpath $outDir)
mkdir -p $outDir

##############################################################################
# MAIN                                                                       #
##############################################################################
hostWD=$(realpath $outDir)

# create a folder named $name and copy the fasta file to it
mkdir -p $hostWD/$name
fastaName=$(basename $fastaPath)
[[ ! -f $hostWD/$name/$fastaName ]] && cp $fastaPath $hostWD/$name/
# time log
[[ ! -f $hostWD/$name/time.log ]] && echo "name: $name" > $hostWD/$name/time.log

# --------------------------------------
# Sequence Alignment
# --------------------------------------
RUN_MSA=true
if [[ $PREDICT_STRUCTURE_ONLY == true ]]; then
  RUN_MSA=false
fi

if [[ $RUN_MSA == true ]]; then
  print_msg "Running seq alignment ..." "INFO"
  start_time=$(date +%s)

  docker run --rm \
    -v $hostWD:/home/vscode/out \
    -v $AFDATA:/mnt/data/alphafold \
    --entrypoint /bin/zsh \
    ${IMAGE_NAME} \
    /home/vscode/entrypoint/run-af2m-msa.sh \
    --fasta /home/vscode/out/${name}/$fastaName \
    --outdir /home/vscode/out/${name} \
    --data /mnt/data/alphafold \
    --jackhmmer_n_cpu $JACKHMMER_N_CPU \
    --hhblits_n_cpu $HHBLITS_N_CPU

  end_time=$(date +%s)
  elapsed_time=$(date -ud "@$((end_time - start_time))" +%T)  # HH:MM:SS e.g. 00:00:10
  print_msg "Running seq alignment ... Done (Elapsed Time: $elapsed_time)" "INFO"
  # write the time to a file
  echo "Generate alignment: $elapsed_time" >> $hostWD/$name/time.log
fi

# ------------------------------------
# Structure Prediction
# ------------------------------------
# determine whether or not to run structure prediction
RUN_STRUCT_PRED=true
if [[ $GENERATE_MSA_ONLY == true ]]; then
  RUN_STRUCT_PRED=false
fi

if [[ $RUN_STRUCT_PRED == true ]]; then
  print_msg "Running structure prediction ..." "INFO"
  start_time=$(date +%s)

  # gpu string, either "all", "'device=0'", "'device=1'"
  gpuStr="all"
  if [[ $GPUDEVICE != "all" ]]; then
    gpuStr="\"device=$GPUDEVICE\""
  fi

  # run structure prediction
  docker run --rm \
    --gpus $gpuStr \
    -v $hostWD:/home/vscode/out \
    -v $AFDATA:/mnt/data/alphafold \
    --entrypoint /bin/zsh \
    ${IMAGE_NAME} \
    /home/vscode/entrypoint/run-af2m-struct.sh \
    --fasta /home/vscode/out/${name}/$fastaName \
    --outdir /home/vscode/out/${name} \
    --data /mnt/data/alphafold \
    --jackhmmer_n_cpu $JACKHMMER_N_CPU \
    --hhblits_n_cpu $HHBLITS_N_CPU

  end_time=$(date +%s)
  elapsed_time=$(date -ud "@$((end_time - start_time))" +%T)  # HH:MM:SS e.g. 00:00:10
  print_msg "Running structure prediction ... Done (Elapsed Time: $elapsed_time)" "INFO"
  echo "Predict  structure: $elapsed_time" >> $hostWD/$name/time.log
fi

# --------------------------------------
# Post processing
# --------------------------------------
if [[ $COMPRESS == true ]]; then
  print_msg "Compressing the output folder ..." "INFO"
  start_time=$(date +%s)

  tar -czf $hostWD/${name}.tar.gz -C $hostWD $name \
  && rm -rf $hostWD/$name

  end_time=$(date +%s)
  elapsed_time=$(date -ud "@$((end_time - start_time))" +%T)  # HH:MM:SS e.g. 00:00:10
  print_msg "Compressing the output folder ... Done (Elapsed Time: $elapsed_time)" "INFO"
fi
