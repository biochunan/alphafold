#!/bin/zsh

# Aim: install alphafold v2.3 dependencies

set -e

# Aim: install alphafold v2.3 dependencies
# Input:
# Output:
# Usage:
# Example:
# Dependencies:

##############################################################################
# FUNCTION                                                                   #
##############################################################################
scriptName=$(basename $0)
usage() {
  echo "Usage: $scriptName [OPTIONS]"
  echo "  --envname, -n <name>      : conda environment name (default: alphafold)"
  echo "  --af2_root_dir, -d <path> : alphafold root directory (default: /home/vscode/alphafold)"
  echo "  --level <level>           : minimum log level (default: INFO)"
  echo "  --help, -h                : display this help"
  # add example
  echo "Example:"
  echo "  $scriptName --conda_env_name alphafold --af2_root_dir /home/vscode/alphafold"
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

##############################################################################
# INPUT                                                                      #
##############################################################################
# Default variables
alphafoldCondaEnvName="alphafold"
alphafoldRootDir="/home/vscode/alphafold"

# Parse command line options
while [[ $# -gt 0 ]]
do
  key="$1"
  case $key in
    --conda_env_name | -n)
      alphafoldCondaEnvName="$2"
      shift 2;;
    --af2_root_dir | -d)
      alphafoldRootDir="$2"
      shift 2;;
    --level)
      MINLOGLEVEL="$2"
      shift 2;; # past argument and value
    --help|-h)
      usage
      shift # past argument
      exit 1;;
    *)
      echo "Illegal option: $key"
      usage
      exit 1;;
  esac
done

##############################################################################
# MAIN                                                                       #
##############################################################################
# activate conda alphafold env
source /miniconda/etc/profile.d/conda.sh
conda activate ${alphafoldCondaEnvName}

# Install pip packages.
pip install -r $alphafoldRootDir/requirements.txt --no-cache-dir
pip install --upgrade --no-cache-dir jax==0.4.10 jaxlib==0.4.10+cuda12.cudnn88 \
    -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html

# downgrade ml_dtypes
pip install --no-cache-dir ml_dtypes==0.2.0

# install alphafold -e
pip install -e $alphafoldRootDir

# clean up
conda clean --all --force-pkgs-dirs --yes
pip cache purge
sudo apt autoremove -y
sudo rm -rf /var/lib/apt/lists/*
sudo apt-get clean