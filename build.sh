#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Config
# -----------------------------
MD_INPUT="${1:-test.md}"          # source markdown
NAME="${2:-budo-notes}"           # base output name
OUT_DIR="output"
TMP_DIR="$(mktemp -d)"

A6_PDF="$OUT_DIR/${NAME}-a6.pdf"
IMPOSED="$OUT_DIR/${NAME}-imposed-a4.pdf"

# Font (must exist on your system)
MAINFONT="${MAINFONT:-Noto Serif CJK JP}"

# Pandoc options
PANDOC_ENGINE="xelatex"
PANDOC_A6_OPTS=(
  --pdf-engine="$PANDOC_ENGINE"
  -H header.tex
  -V titlepage=true
  --toc
  -V toc-title="Index"
  -V "papersize=A6"
  -V "fontsize=11pt"
  -V "geometry:margin=1.2cm"
  -V "mainfont=$MAINFONT"
)

# -----------------------------
# Helpers
# -----------------------------
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌ Missing command: $1"
    exit 1
  }
}

# Map a page number to either:
# - "$IN:NUM" if within range
# - "blank.pdf" if beyond range (padding)
page_ref() {
  local page="$1"
  local real_pages="$2"
  local _in_pdf="$3"   # kept only to avoid changing call sites

  if (( page <= real_pages )); then
    echo "$PAGES_DIR/p-$page.pdf"
  else
    echo "$TMP_DIR/blank-a6.pdf"
  fi
}

# -----------------------------
# Checks
# -----------------------------
mkdir -p "$OUT_DIR"
need_cmd pandoc
need_cmd pdfjam
need_cmd pdfinfo

# -----------------------------
# 1) Build A6 reading PDF
# -----------------------------
echo "▶ Pandoc → A6 PDF: $A6_PDF"
pandoc "$MD_INPUT" "${PANDOC_A6_OPTS[@]}" -o "$A6_PDF"

# -----------------------------
# 2) Count pages
# -----------------------------
REAL_PAGES="$(pdfinfo "$A6_PDF" | awk '/^Pages:/ {print $2}')"
if [[ -z "$REAL_PAGES" ]]; then
  echo "❌ Could not determine page count with pdfinfo"
  exit 1
fi
echo "ℹ️  Pages (real): $REAL_PAGES"

# Pad to multiple of 8
PADDED_PAGES=$(( (REAL_PAGES + 7) / 8 * 8 ))
SHEETS=$(( PADDED_PAGES / 8 ))
echo "ℹ️  Pages (padded): $PADDED_PAGES  |  A4 sheets: $SHEETS"

# -----------------------------
# 3) Create a blank A6 page (used for padding)
# -----------------------------
echo "▶ Creating blank A6 page for padding (LaTeX)..."

cat > "${TMP_DIR}/blank.tex" <<'EOF'
\documentclass{article}
\usepackage[a6paper,margin=0cm]{geometry}
\pagestyle{empty}
\begin{document}
\mbox{}
\end{document}
EOF

xelatex -interaction=nonstopmode -output-directory "$TMP_DIR" "${TMP_DIR}/blank.tex" >/dev/null

mv "${TMP_DIR}/blank.pdf" "${TMP_DIR}/blank-a6.pdf"

# -----------------------------
# 4) Generate imposed A4 pages (front/back) per sheet
#    Rule for each block of 8 pages starting at s:
#      a=s, b=s+1, c=s+2, d=s+3, e=s+4, f=s+5, g=s+6, h=s+7
#      FRONT: [h, a, f, c]
#      BACK : [b, g, d, e]
# -----------------------------
echo "▶ Imposing to A4 (4-up per side) ..."

MERGE_LIST=()

# Split A6 into single-page PDFs (so pdfjam can take real files)
PAGES_DIR="$TMP_DIR/pages"
mkdir -p "$PAGES_DIR"
pdfseparate "$A6_PDF" "$PAGES_DIR/p-%d.pdf" >/dev/null

for ((k=0; k<SHEETS; k++)); do
  Np="$PADDED_PAGES"

  # FRONT
  F1_NUM=$((Np - 4*k))
  F2_NUM=$((1 + 4*k))
  F3_NUM=$((Np - 2 - 4*k))
  F4_NUM=$((3 + 4*k))

  # BACK
  B1_NUM=$((2 + 4*k))
  B2_NUM=$((Np - 1 - 4*k))
  B3_NUM=$((4 + 4*k))
  B4_NUM=$((Np - 3 - 4*k))

  F1="$(page_ref "$F1_NUM" "$REAL_PAGES" "$A6_PDF")"
  F2="$(page_ref "$F2_NUM" "$REAL_PAGES" "$A6_PDF")"
  F3="$(page_ref "$F3_NUM" "$REAL_PAGES" "$A6_PDF")"
  F4="$(page_ref "$F4_NUM" "$REAL_PAGES" "$A6_PDF")"

  B1="$(page_ref "$B1_NUM" "$REAL_PAGES" "$A6_PDF")"
  B2="$(page_ref "$B2_NUM" "$REAL_PAGES" "$A6_PDF")"
  B3="$(page_ref "$B3_NUM" "$REAL_PAGES" "$A6_PDF")"
  B4="$(page_ref "$B4_NUM" "$REAL_PAGES" "$A6_PDF")"

  echo "• Sheet $((k+1)) A: $F1_NUM,$F2_NUM,$F3_NUM,$F4_NUM | B: $B1_NUM,$B2_NUM,$B3_NUM,$B4_NUM"

  FRONT_PDF="${TMP_DIR}/sheet-$((k+1))-front.pdf"
  BACK_PDF="${TMP_DIR}/sheet-$((k+1))-back.pdf"

  PREAMBLE_FILE="$(pwd)/cutmarks.tex"

  pdfjam "$F1" "$F2" "$F3" "$F4" \
    --nup 2x2 \
    --paper a4paper \
    --preamble "\\input{$PREAMBLE_FILE}" \
    --outfile "$FRONT_PDF" >/dev/null

  pdfjam "$B1" "$B2" "$B3" "$B4" \
    --nup 2x2 \
    --paper a4paper \
    --preamble "\\input{$PREAMBLE_FILE}" \
    --outfile "$BACK_PDF" >/dev/null

  MERGE_LIST+=("$FRONT_PDF" "$BACK_PDF")
done

# -----------------------------
# 5) Merge all imposed pages into a single PDF
# -----------------------------
echo "▶ Merging into: $IMPOSED"
pdfjam "${MERGE_LIST[@]}" --outfile "$IMPOSED" >/dev/null

echo ""
echo "✅ Done."
echo "📖 A6 reading PDF:  $A6_PDF"
echo "🖨️ A4 imposed PDF:  $IMPOSED"
echo ""
echo "Print settings (IMPORTANT):"
echo " - Paper: A4"
echo " - Flip: LONG edge"
echo "Then cut as you planned."