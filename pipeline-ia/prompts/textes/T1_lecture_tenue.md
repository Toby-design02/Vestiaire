---
modele: voir config.json (modeles.lecture)
entree: 1 à 3 photos d'une même séance (même personne, même tenue), recadrées sur la personne
sortie: JSON uniquement
variables: {{angles}}
---
Ces photos montrent la même personne, dans la même tenue, sous des angles différents ({{angles}}).
Une photo marquée « sans_visage » peut montrer le dos de la personne ou quelqu'un d'autre : utilise-la seulement si on y voit clairement la même tenue que sur les autres photos, sinon ignore-la.
Liste chaque vêtement et accessoire porté par cette personne. Ignore les autres personnes.
Si aucune tenue n'est visible (document, capture d'écran, paysage), réponds {"pieces": []}.

Réponds uniquement en JSON :
{"pieces":[{
 "rayon": "veste|pull|haut|bas|chaussures|accessoire",
 "type": "ex. chemise, jean, pull col rond",
 "couleurs": ["couleur principale", "..."],
 "motif": "uni|rayé|carreaux|imprimé|logo|autre",
 "matiere": "si visible, sinon null",
 "coupe_col": "détails de coupe et de col, court",
 "details_face": "court",
 "details_dos": "court, null si dos non visible",
 "logos_textes": "texte exact lu ou description du logo, sinon null",
 "marque_probable": "seulement si lisible, sinon null",
 "boite": [x0, y0, x1, y1, "indice de la photo"],
 "confiance": 0.0
}]}
Coordonnées de "boite" en millièmes de la photo (0 à 1000). Sois bref.
