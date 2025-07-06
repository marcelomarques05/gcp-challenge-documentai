#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="${SCRIPT_DIR}/../frontend"
VENV_DIR="${FRONTEND_DIR}/.venv"

SUMMARY_FILE=""

usage() {
  cat <<EOF
Usage: $0 [--summary-file FILE] [-h|--help]

Options:
  --summary-file FILE   Start frontend using the specified summary file.
  -h, --help             Show this help message and exit.

If --summary-file is not provided, the script checks for environment variables:
  PROJECT_ID, BUCKET_NAME, DATASET_NAME, TABLE_NAME.
If any are missing, you will be prompted to enter them.

A Python virtual environment will always be created and used in frontend/.venv.
Required packages will be installed from requirements.txt if not present.
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary-file)
      if [[ -z "${2-}" ]]; then
        echo "Error: --summary-file requires a file path argument."
        exit 1
      fi
      SUMMARY_FILE="$2"
      # Convert to absolute path in case working directory changes later
      SUMMARY_FILE="$(realpath "$SUMMARY_FILE")"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

cd "$FRONTEND_DIR"

# Create virtual environment if it doesn't exist
if [[ ! -d "$VENV_DIR" ]]; then
  echo "Creating Python virtual environment in $VENV_DIR"
  python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Install required packages if needed
if ! pip show Flask &>/dev/null; then
  echo "Installing required packages from requirements.txt..."
  pip install --upgrade pip
  pip install -r requirements.txt
fi

# If no summary file, check for required env vars or prompt
if [[ -z "$SUMMARY_FILE" ]]; then
  : "${PROJECT_ID:=$(read -rp 'Enter PROJECT_ID: ' var; echo $var)}"
  : "${BUCKET_NAME:=$(read -rp 'Enter BUCKET_NAME: ' var; echo $var)}"
  : "${DATASET_NAME:=$(read -rp 'Enter DATASET_NAME: ' var; echo $var)}"
  : "${TABLE_NAME:=$(read -rp 'Enter TABLE_NAME: ' var; echo $var)}"
fi

export FLASK_APP=main.py
export FLASK_ENV=development

if [[ -n "$SUMMARY_FILE" ]]; then
  echo "Starting frontend with summary file: $SUMMARY_FILE"
  echo "Parsing summary file: $SUMMARY_FILE"
  
  # Extrair variáveis do arquivo
  PROJECT_ID=$(grep -E "^Project ID:" "$SUMMARY_FILE" | awk -F': *' '{print $2}')
  BUCKET_NAME=$(grep -E "^\s*-\s*challenge-main-bucket" "$SUMMARY_FILE" | awk '{print $2}' | head -n1)
  DATASET_NAME=$(grep -E "^  - Dataset:" "$SUMMARY_FILE" | awk -F': *' '{print $2}')
  TABLE_NAME=$(grep -E "^  - Table:" "$SUMMARY_FILE" | awk -F': *' '{print $2}')

  if [[ -z "$PROJECT_ID" || -z "$BUCKET_NAME" || -z "$DATASET_NAME" || -z "$TABLE_NAME" ]]; then
    echo "Error: Could not extract all required variables from $SUMMARY_FILE"
    exit 1
  fi

  export PROJECT_ID BUCKET_NAME DATASET_NAME TABLE_NAME
else
  : "${PROJECT_ID:=$(read -rp 'Enter PROJECT_ID: ' var; echo $var)}"
  : "${BUCKET_NAME:=$(read -rp 'Enter BUCKET_NAME: ' var; echo $var)}"
  : "${DATASET_NAME:=$(read -rp 'Enter DATASET_NAME: ' var; echo $var)}"
  : "${TABLE_NAME:=$(read -rp 'Enter TABLE_NAME: ' var; echo $var)}"
  export PROJECT_ID BUCKET_NAME DATASET_NAME TABLE_NAME
fi

# 🌟 Mostrar as variáveis configuradas
echo
echo "✅ Frontend will use the following configuration:"
echo "  PROJECT_ID   = $PROJECT_ID"
echo "  BUCKET_NAME  = $BUCKET_NAME"
echo "  DATASET_NAME = $DATASET_NAME"
echo "  TABLE_NAME   = $TABLE_NAME"
echo

export FLASK_APP=main.py
export FLASK_ENV=development

python3 -m flask run --host=0.0.0.0 --port=8080