#!/bin/zsh
# Sauvegarde hebdomadaire du projet sur GitHub.
# Lancé automatiquement chaque lundi à 10 h par la tâche programmée « Sauvegarde GitHub du projet Vestiaire »
# de l'app Claude (macOS interdit aux tâches de fond classiques de lire le dossier Documents).
# On peut aussi le lancer à la main : zsh tools/sauvegarde-github.sh

cd "$(dirname "$0")/.." || exit 1
echo "--- $(date '+%d/%m/%Y %H:%M') ---"

git add -A
if git diff --cached --quiet; then
    echo "Aucune modification depuis la dernière sauvegarde."
else
    git commit -q -m "Sauvegarde automatique du $(date '+%d/%m/%Y')" && echo "Nouvelle version enregistrée."
fi

# Envoie aussi les versions enregistrées entre-temps (par exemple par Claude).
git push -q origin main && echo "GitHub est à jour."
