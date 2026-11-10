#!/bin/bash
# Essai comparatif (≈ 5 $ max) sur les tenues d'oct. 2025 à fév. 2026, recadrages en 1280 px :
#   1. Haiku puis Sonnet lisent et regroupent les mêmes tenues (runs/haiku, runs/sonnet)
#   2. 4 pièces générées avec plusieurs modèles d'image → runs/sonnet/out/comparaison/planche.jpg
set -e
cd "$(dirname "$0")"
for run in haiku sonnet; do
  echo "=== $run ==="
  RUN=$run python3 algo/select_views.py | grep -v WARN
  RUN=$run python3 algo/lecture.py soumettre
  RUN=$run python3 algo/lecture.py recuperer
  RUN=$run python3 algo/dedoublonnage.py | grep -v WARN
done
RUN=sonnet python3 algo/comparer_images.py
for run in haiku sonnet; do echo "$run : $(python3 -c "import json;print(round(json.load(open('runs/$run/data/depenses.json'))['total_usd'],3))") \$"; done
