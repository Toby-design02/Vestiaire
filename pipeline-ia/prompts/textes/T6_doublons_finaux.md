---
modele: voir config.json (modeles.arbitrage)
entree: une planche de pièces numérotées ; chaque case = photo produit générée (à gauche) + vraie photo (à droite)
sortie: JSON uniquement
variables: {{n}} {{famille}}
---
Chaque case numérotée (1 à {{n}}) montre une pièce de la garde-robe d'une même personne ({{famille}}) : à gauche sa photo produit, à droite une vraie photo où elle la porte.
Certaines cases sont en double : la même pièce réelle, comptée deux fois. Trouve-les.
Ne regroupe que si les vraies photos montrent la même pièce, avec les mêmes détails (couleur exacte, matière, col, poches, boutons, logos, motif, usure). Une personne peut posséder plusieurs pièces très proches (plusieurs t-shirts blancs, plusieurs jeans) : dans le doute, ne regroupe pas.
Réponds uniquement avec le JSON, sans ``` ni texte autour : {"doublons": [[numéros de la même pièce], …]} ; {"doublons": []} s'il n'y en a pas.
