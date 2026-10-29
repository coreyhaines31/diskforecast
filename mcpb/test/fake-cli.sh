#!/bin/sh
# Stands in for the diskforecast CLI in the smoke test. FAKE_MODE picks the behavior.
case "$FAKE_MODE" in
  json-error) echo '{"error":"fake json error"}'; exit 1 ;;
  stderr) echo "diskforecast: fake stderr error" >&2; exit 1 ;;
  *) printf '{"argv":"%s"}\n' "$*" ;;
esac
