#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="${SCRIPT_DIR}/../frontend"
VENV_DIR="${FRONTEND_DIR}/.venv"

SUMMARIES_FILE=""

usage() {
  cat <<EOF
Usage: $0 [--summaries-file FILE] [-h|--help]

Options:
  --summaries-file FILE   Start frontend using the specified summaries file.
  -h, --help             Show this help message and exit.

If --summaries-file is not provided, the script checks for environment variables:
  PROJECT_ID, BUCKET_NAME, DATASET_NAME, TABLE_NAME.
If any are missing, you will be prompted to enter them.

A Python virtual environment will always be created and used in frontend/.venv.
Required packages will be installed from requirements.txt if not present.
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --summaries-file)
      if [[ -z "${2-}" ]]; then
        echo "Error: --summaries-file requires a file path argument."
        exit 1
      fi
      SUMMARIES_FILE="$2"
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

# If no summaries file, check for required env vars or prompt
if [[ -z "$SUMMARIES_FILE" ]]; then
  : "${PROJECT_ID:=$(read -rp 'Enter PROJECT_ID: ' var; echo $var)}"
  : "${BUCKET_NAME:=$(read -rp 'Enter BUCKET_NAME: ' var; echo $var)}"
  : "${DATASET_NAME:=$(read -rp 'Enter DATASET_NAME: ' var; echo $var)}"
  : "${TABLE_NAME:=$(read -rp 'Enter TABLE_NAME: ' var; echo $var)}"
fi

export FLASK_APP=main.py
export FLASK_ENV=development

if [[ -n "$SUMMARIES_FILE" ]]; then
  echo "Starting frontend with summaries file: $SUMMARIES_FILE"
  export SUMMARIES_FILE
else
  echo "Starting frontend with GCP variables:"
  echo "  PROJECT_ID=$PROJECT_ID"
  echo "  BUCKET_NAME=$BUCKET_NAME"
  echo "  DATASET_NAME=$DATASET_NAME"
  echo "  TABLE_NAME=$TABLE_NAME"
  export PROJECT_ID BUCKET_NAME DATASET_NAME TABLE_NAME
fi

python3 -m flask run --host=0.0.0.0 --port=8080
