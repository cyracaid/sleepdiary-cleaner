#!/usr/bin/env bash
set -euo pipefail

echo "=== SPL Sleep Pipeline ==="
echo ""

# Install/update the package if needed
if ! Rscript -e 'library(splsleep)' 2>/dev/null; then
  echo "Installing splsleep package..."
  Rscript -e 'devtools::install(".", dependencies = TRUE, upgrade = "never")'
fi

# Run the pipeline via the package
Rscript -e '
library(splsleep)
splsleep_loaded <- TRUE
run_pipeline()
'

echo ""
echo "=== Pipeline complete ==="
