#!/bin/bash

# Execute the scripts in order
#bash scripts/apps/00-web-component.sh

WORKING_DIR="application/chat-interface"

cd "$WORKING_DIR" || { echo "Directory $WORKING_DIR not found."; exit 1; }

bash publish-build.sh
bash deploy-to-cloud-run.sh