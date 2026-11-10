#!/bin/bash
# Étapes payantes (Claude Haiku + gpt-image-1-mini), à lancer dans le Terminal du Mac.
#   ./etapes_api.sh mini   → 20 tenues lues, 10 photos produit (quelques centimes)
#   ./etapes_api.sh tout   → toute la galerie (plafond : budget_max_usd dans config.json)
# Les étapes gratuites (lire_galerie, detect, select_views) doivent avoir tourné avant.
set -e
cd "$(dirname "$0")"
MODE=${1:-mini}
python3 -m pip install -q --user -r requirements.txt 2>/dev/null || python3 -m pip install -q --user --break-system-packages -r requirements.txt
if [ "$MODE" = "mini" ]; then python3 algo/lecture.py soumettre 20; else python3 algo/lecture.py soumettre; fi
python3 algo/lecture.py recuperer
python3 algo/dedoublonnage.py
python3 algo/generation.py "$MODE"
python3 algo/fusion_finale.py
python3 algo/export_app.py
echo
echo "Dépense totale :"; python3 -c "import json;d=json.load(open('data/depenses.json'));print(round(d['total_usd'],4),'\$')"
