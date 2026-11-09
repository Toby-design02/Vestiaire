---
modele: voir config.json (modeles.arbitrage)
entree: les 1 à 3 photos de la pièce qui seront envoyées au générateur d'images
sortie: JSON uniquement
variables: {{description}}
---
Ces photos montrent une même pièce : {{description}}.
Un générateur d'images va s'en servir pour créer une photo produit de cette pièce, posée à plat, vue de face, entière.
Ces photos suffisent-elles pour la reproduire fidèlement, sans rien inventer : sa forme entière, son col, ses manches ou jambes, ses couleurs, et la totalité de ses logos ou textes ?
Si une partie importante n'est visible sur aucune photo (bas de la pièce, manches, une partie du logo cachée), réponds non.
Si les photos ne montrent pas toutes exactement la même pièce, réponds non.
Réponds uniquement avec le JSON, sans ``` ni texte autour : {"suffisant": true ou false, "manque": "ce qui manque, en 6 mots maximum, ou null"}
