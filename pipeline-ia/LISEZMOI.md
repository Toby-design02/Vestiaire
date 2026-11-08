# Pipeline IA · Algo 1 : de la galerie au dressing

Reconstitue le vestiaire à partir des photos où l'utilisateur apparaît, puis génère une photo produit de chaque pièce. L'app iOS (dossier `Vestiaire/` à la racine du dépôt) lira les fiches produites ici, au format de `docs/modele-de-donnees.md`.

## Les étapes

| Étape | Script | Outil | Coût |
| --- | --- | --- | --- |
| 0. Lecture de la photothèque (photos seulement, sans vidéos ni captures d'écran), comme l'app sur l'iPhone | `outils/lire_galerie.swift` | PhotoKit sur le Mac | 0 |
| 1a. Dates, personnes, visages | `algo/detect.py` | modèles OpenCV en local | 0 |
| 1b. Reconnaissance, séances, angles (face, profil, plein pied, sans visage), meilleures vues, recadrages | `algo/select_views.py` | code | 0 |
| 2. Lecture des tenues → fiche JSON de chaque pièce | `algo/lecture.py` | Claude Haiku 5.5, API Batch | ≈ 0,05 à 0,15 $ |
| 3. Regroupement des photos de chaque pièce (couleurs réelles, puis Haiku si doute), choix des meilleures vues (pièce entière, logo lisible, angles variés) ; une pièce sans photo suffisante est notée « photos insuffisantes » et n'est pas générée | `algo/dedoublonnage.py` | code, et Haiku seulement si ambigu | ≈ 0,02 $ |
| 4. Photo produit de chaque pièce | `algo/generation.py` | gpt-image-1-mini + prompt P1 | ≈ 0,005 à 0,011 $ par pièce |
| 5. Export au format de l'app (`Item`, `Session`, `WearEvent`) | `algo/export_app.py` | code | 0 |

Seuls les recadrages basse résolution de l'utilisateur (étape 1b) sont envoyés aux API, jamais les photos brutes. Le plafond de dépense est dans `config.json` (`budget_max_usd`, 1 $ par défaut) : les scripts s'arrêtent avant de le dépasser. Le détail est dans `data/depenses.json`.

Test du 30 oct. 2026 sur 8 374 photos : 5 365 depuis 2023, l'utilisateur reconnu sur 4 255, 454 séances, 979 recadrages. La photo de dos avec le logo Zadig & Voltaire a été retrouvée automatiquement.

## Les prompts

Dans `prompts/`. Modifie le texte librement ; garde les variables entre accolades (`{{description}}`…), le code les remplace.

- `prompts/images/P1_photo_produit.md` : photo produit de chaque pièce.
- `prompts/textes/T1_lecture_tenue.md` : lecture des tenues par Haiku.

## Lancer le pipeline sur un Mac

Dans le Terminal :

```bash
# 1. Récupérer le code (une seule fois)
git clone https://github.com/Toby-design02/Vestiaire.git
cd Vestiaire/pipeline-ia
pip3 install -r requirements.txt
./telecharger_modeles.sh

# 2. Le selfie de référence : un selfie récent, de face, nommé selfie.jpg, dans pipeline-ia/
#    (comme l'onboarding de l'app : c'est lui qui dit à l'algo qui tu es).

# 3. Les clés API : copier .env.exemple en .env et y coller les deux clés.
[ -f .env ] || cp .env.exemple .env   # ne remplace jamais un .env existant

# 3 bis. La photothèque, sans rien exporter : le Mac demande l'accès aux photos, comme l'iPhone.
swiftc -O outils/lire_galerie.swift -o outils/lire_galerie && ./outils/lire_galerie

# 4. Étapes gratuites
python3 algo/detect.py            # se relance où il s'est arrêté si on le coupe
python3 algo/select_views.py

# 5. Mini-test payant (quelques centimes)
python3 algo/lecture.py soumettre 20
python3 algo/lecture.py recuperer
python3 algo/dedoublonnage.py
python3 algo/generation.py mini   # 10 photos produit dans out/produits/

# 6. Si le résultat est bon : toute la galerie
python3 algo/lecture.py soumettre
python3 algo/lecture.py recuperer
python3 algo/dedoublonnage.py
python3 algo/generation.py tout

# 7. Pour l'app : out/app/dressing.json + out/app/images/
python3 algo/export_app.py
```

Les sorties (`data/`, `out/`), le selfie et le fichier `.env` restent sur l'ordinateur : ils sont exclus de GitHub (`.gitignore`), car ils contiennent des photos et des données personnelles.
