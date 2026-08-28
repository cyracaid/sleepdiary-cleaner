#!/usr/bin/env bash
set -euo pipefail

echo "=== SPL Sleep Pipeline ==="
echo ""

# Install/update the package if needed
if ! Rscript -e 'library(sleepcleanr)' 2>/dev/null; then
  echo "Installing sleepcleanr package..."
  Rscript -e 'devtools::install(".", dependencies = TRUE, upgrade = "never")'
fi

# Run the pipeline via the package
Rscript -e '
library(sleepcleanr)
sleepcleanr_loaded <- TRUE
run_pipeline()
'

echo ""
echo "=== Pipeline complete ==="
