#!/usr/bin/env bash
set -euo pipefail
# pnpm fsd:check 2>&1 | tee fsd.log
log_file="${1:-fsd.log}"
output_file="${2:-issues.tsv}"

if [ ! -s "$log_file" ]; then
  echo "fsd\t(see full log below)\tfsd.log not found or empty." >> "$output_file"
  exit 0
fi

awk '
  function strip_ansi(line) {
    gsub(/\033\[[0-9;]*[A-Za-z]/,"",line)
    gsub(/\033\[[0-9;]*m/,"",line)
    gsub(/[[:cntrl:]]/,"",line)
    return line
  }
  function strip_prefix(line) {
    line=strip_ansi(line)
    sub(/^[^[:alnum:]]+/,"",line)
    return line
  }
  $0 ~ /(fsd\/|https?:\/\/)/ { next }
  $0 ~ /This[[:space:]]/ {
    msg=strip_prefix($0)
    if (file!="") print "fsd\t" file "\t" msg
    next
  }
  {
    line=strip_prefix($0)
    if (line=="") next
    if (match(line, /(src\/[^[:space:]]+|app\/[^[:space:]]+|shared\/[^[:space:]]+|features\/[^[:space:]]+|entities\/[^[:space:]]+|widgets\/[^[:space:]]+|pages\/[^[:space:]]+|processes\/[^[:space:]]+)/)) {
      file=substr(line, RSTART, RLENGTH)
      next
    }
    if (file!="") {
      print "fsd\t" file "\t" line
      next
    }
  }
' "$log_file" >> "$output_file" || true

if ! grep -q "^fsd\t" "$output_file" 2>/dev/null; then
  echo "fsd\t(see full log below)\tParser did not match FSD output format." >> "$output_file"
fi
