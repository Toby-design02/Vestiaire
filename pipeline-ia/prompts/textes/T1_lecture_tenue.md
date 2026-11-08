---
modele: voir config.json (modeles.lecture)
entree: 1 à 3 photos d'une même séance (même personne, même tenue), recadrées sur la personne
sortie: JSON uniquement
variables: {{angles}}
---
Ces photos montrent la même personne, dans la même tenue, sous des angles différents ({{angles}}).
Une photo marquée « sans_visage » peut montrer le dos de la personne ou quelqu'un d'autre : utilise-la seulement si on y voit clairement la même tenue que sur les autres photos, sinon ignore-la.
Liste chaque vêtement et accessoire porté par cette personne et clairement visible. Ignore les autres personnes et les pièces trop coupées pour être décrites.
Si aucune tenue n'est visible (document, capture d'écran, paysage), réponds {"pieces": []}.

Réponds uniquement avec le JSON, sans ``` ni texte autour :
{"pieces":[{
 "rayon": "veste|pull|haut|bas|chaussures|accessoire",
 "type": "ex. chemise, jean, pull col rond",
 "couleurs": ["couleur principale", "..."],
 "motif": "uni|rayé|carreaux|imprimé|logo|autre",
 "matiere": "si visible, sinon null",
 "coupe_col": "détails de coupe et de col, court",
 "details_face": "court",
 "details_dos": "court, null si dos non visible",
 "logos_textes": "texte exact lu (… pour une partie cachée) ou description du logo, sinon null",
 "visible": "entier|partiel",
 "logo_complet": true,
 "marque_probable": "seulement si lisible, sinon null",
 "boite": [x0, y0, x1, y1, "indice de la photo"],
 "confiance": 0.0
}]}
"visible" : entier si toute la pièce ou presque est visible ; partiel si une partie importante est cachée (par une autre pièce, un bras, un objet) ou hors cadre.
"logo_complet" : true si le logo ou le texte est entièrement lisible ; false si une partie est cachée (veste ouverte, bras, pli, cadrage) ; null s'il n'y en a pas.
Coordonnées de "boite" en millièmes de la photo (0 à 1000).
Sois très bref : 6 mots maximum par texte, null quand ce n'est pas visible.
