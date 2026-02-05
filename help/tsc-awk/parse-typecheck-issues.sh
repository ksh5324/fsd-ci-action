#!/usr/bin/env bash
set -euo pipefail

log_file="${1:-typecheck.log}"
output_file="${2:-issues.tsv}"

if [ ! -s "$log_file" ]; then
  echo "typecheck\t(see full log below)\ttypecheck.log not found or empty." >> "$output_file"
  exit 0
fi

awk '
  function strip_ansi(line) {
    gsub(/\033\[[0-9;]*[A-Za-z]/,"",line)
    gsub(/\033\[[0-9;]*m/,"",line)
    gsub(/[[:cntrl:]]/,"",line)
    return line
  }
  {
    line=strip_ansi($0)
    if (line ~ /error TS[0-9]+:/) {
      msg=line
      sub(/^[^:]+:[[:space:]]*/, "", msg)
      if (match(line, /(src\/[^[:space:]]+|app\/[^[:space:]]+|shared\/[^[:space:]]+|features\/[^[:space:]]+|entities\/[^[:space:]]+|widgets\/[^[:space:]]+|pages\/[^[:space:]]+|processes\/[^[:space:]]+)/)) {
        file=substr(line, RSTART, RLENGTH)
      } else {
        file="(unknown)"
      }
      print "typecheck\t" file "\t" msg
      next
    }
  }
' "$log_file" >> "$output_file" || true
