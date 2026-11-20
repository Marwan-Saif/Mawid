#!/usr/bin/env bash
# Fails the build if a layer imports something it must not know about.
#   domain/       → no Flutter UI, no HTTP, no data layer
#   presentation/ → no data sources or models (only domain + core)
set -euo pipefail
cd "$(dirname "$0")/.."
status=0

bad_domain=$(grep -rnE "import '(package:flutter/|package:http/|package:shared_preferences/|.*/data/)" lib/features/*/domain || true)
if [ -n "$bad_domain" ]; then
  echo "Domain layer must stay pure Dart:"; echo "$bad_domain"; status=1
fi

bad_presentation=$(grep -rnE "import '.*/data/(datasources|models)/" lib/features/*/presentation || true)
if [ -n "$bad_presentation" ]; then
  echo "Presentation must not import data sources or models:"; echo "$bad_presentation"; status=1
fi

[ $status -eq 0 ] && echo "Layer boundaries OK"
exit $status
