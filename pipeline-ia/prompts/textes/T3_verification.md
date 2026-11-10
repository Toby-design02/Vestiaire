---
modele: voir config.json (modeles.arbitrage)
entree: les 1 à 3 photos de la pièce qui seront envoyées au générateur d'images
sortie: JSON uniquement
variables: {{description}}
---
Ces photos montrent une même pièce : {{description}}.
Un générateur d'images va s'en servir pour créer une photo produit de cette pièce, posée à plat et vue de face.
Les parties standard peuvent être déduites sans risque : le dos, les ourlets, le bas d'une chemise rentrée, les poignets, le bas d'un jean caché par les chaussures. Ne réponds pas non pour elles.
Réponds non seulement si :
- les photos ne montrent pas toutes la même pièce ;
- un logo, un texte ou un motif distinctif n'est que partiellement visible ;
- on ne voit pas assez la pièce pour connaître sa couleur, sa matière, son col et sa coupe générale.
Réponds uniquement avec le JSON, sans ``` ni texte autour : {"suffisant": true ou false, "manque": "la raison, en 6 mots maximum, ou null"}
