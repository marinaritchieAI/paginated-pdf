#!/usr/bin/env bash
# checker.sh — verify a paginated .sheet document before it ships.
#
#   bash checker.sh /absolute/path/doc.html [/absolute/path/doc.pdf]
#
# Checks the things a script can check, so a human only has to look at the
# things a script cannot. Exits non-zero and lists every failure.

set -uo pipefail

HTML="${1:-}"
PDF="${2:-}"

if [ -z "$HTML" ]; then
  echo "usage: bash checker.sh <doc.html> [doc.pdf]" >&2
  exit 2
fi
if [ ! -f "$HTML" ]; then
  echo "FAIL  html not found: $HTML" >&2
  exit 2
fi

fails=0
fail() { echo "FAIL  $1"; fails=$((fails + 1)); }
pass() { echo "ok    $1"; }
skip() { echo "skip  $1"; }

# ---------------------------------------------------------------- sheets
sheets=$(grep -o 'class="sheet"' "$HTML" | wc -l | tr -d ' ')
if [ "$sheets" -eq 0 ]; then
  fail "no elements with class=\"sheet\" found; this is not a paginated document"
  exit 1
fi
pass "$sheets sheets in the html"

# ---------------------------------------------------------------- footers
# Canonical footer number markup is:  <b>2</b> / 5
pairs=$(grep -oE '<b>[0-9]+</b>[[:space:]]*/[[:space:]]*[0-9]+' "$HTML" \
        | sed -E 's:<b>([0-9]+)</b>[[:space:]]*/[[:space:]]*([0-9]+):\1 \2:')

if [ -z "$pairs" ]; then
  fail "no page numbers matching '<b>n</b> / N' found in any footer"
else
  footers=$(printf '%s\n' "$pairs" | wc -l | tr -d ' ')

  if [ "$footers" -ne "$sheets" ]; then
    fail "$sheets sheets but $footers page numbers; every sheet needs a footer"
  else
    pass "every sheet carries a page number"
  fi

  # one distinct total across the whole document
  totals=$(printf '%s\n' "$pairs" | awk '{print $2}' | sort -u)
  if [ "$(printf '%s\n' "$totals" | wc -l | tr -d ' ')" -ne 1 ]; then
    fail "page totals disagree: $(printf '%s ' $totals)"
    declared=""
  else
    declared="$totals"
    pass "all footers declare the same total: / $declared"

    if [ "$declared" -ne "$sheets" ]; then
      fail "footers say / $declared but the document has $sheets sheets"
    else
      pass "declared total matches the sheet count"
    fi

    # one footer for every page from 1 to N, none missing, none doubled
    missing=""
    dupes=""
    for n in $(seq 1 "$declared"); do
      c=$(printf '%s\n' "$pairs" | awk -v n="$n" '$1 == n' | wc -l | tr -d ' ')
      [ "$c" -eq 0 ] && missing="$missing $n"
      [ "$c" -gt 1 ] && dupes="$dupes $n(x$c)"
    done
    [ -n "$missing" ] && fail "no footer for page:$missing"
    [ -n "$dupes" ] && fail "page number used more than once:$dupes"
    [ -z "$missing" ] && [ -z "$dupes" ] && pass "pages 1 to $declared each appear exactly once"
  fi
fi

# ---------------------------------------------------------------- placeholders
leftovers=$(grep -oE '\{\{[A-Z0-9_]+\}\}' "$HTML" | sort -u | tr '\n' ' ')
if [ -n "$leftovers" ]; then
  fail "unresolved placeholders: $leftovers"
else
  pass "no unresolved {{TOKEN}} placeholders"
fi

# ---------------------------------------------------------------- the pdf
if [ -z "$PDF" ]; then
  skip "no pdf given; render it and re-run with the pdf path to check the output"
elif [ ! -f "$PDF" ]; then
  fail "pdf not found: $PDF"
elif ! command -v pdfinfo >/dev/null 2>&1; then
  skip "poppler not installed, cannot inspect the pdf (brew install poppler)"
else
  pages=$(pdfinfo "$PDF" | awk -F: '/^Pages/ {gsub(/ /,"",$2); print $2}')
  if [ "$pages" -ne "$sheets" ]; then
    fail "pdf has $pages pages but the html has $sheets sheets"
  else
    pass "pdf page count matches the sheet count: $pages"
  fi

  size=$(pdfinfo "$PDF" | grep '^Page size' | sed 's/^Page size: *//')
  # Chrome reports A4 as "594.96 x 841.92 pts (A4)", so match the name first
  # and fall back to the numbers with a point of tolerance either way.
  case "$size" in
    *"(A4)"*)      pass "page size is A4 ($size)" ;;
    *59[3-6]*84[0-3]*) pass "page size is A4 ($size)" ;;
    *) fail "page size is not A4: $size" ;;
  esac

  if command -v pdftotext >/dev/null 2>&1; then
    last=$(pdftotext -layout -f "$pages" -l "$pages" "$PDF" - 2>/dev/null | tr -d '[:space:]')
    if [ -z "$last" ]; then
      fail "last pdf page is blank; check break-after on the final sheet"
    else
      pass "last pdf page has content, no trailing blank"
    fi
  else
    skip "pdftotext missing, cannot check for a blank trailing page"
  fi
fi

echo
if [ "$fails" -gt 0 ]; then
  echo "$fails check(s) failed. Fix, re-render, re-run."
  exit 1
fi
cat <<'EOT'
All automated checks passed. Now look at the pages yourself:

  pdftoppm -png -r 78 <doc.pdf> /tmp/page

  - no heading stranded at a page bottom with its body overleaf
  - no card, table or quote split across a break
  - background fills and accent colours survived
  - header and footer sit in the same place on every page
EOT
