---
modele: voir config.json (modeles.arbitrage)
entree: une planche de jusqu'à 24 pièces numérotées d'une même famille (une photo par pièce)
sortie: JSON uniquement
variables: {{n}} {{famille}}
---
Ces {{n}} photos numérotées montrent des vêtements ({{famille}}) portés par la même personne, à des jours différents. Chaque photo est censée être une pièce différente de sa garde-robe, mais certaines sont en double : la même pièce photographiée deux fois.
Trouve les doublons : les numéros qui montrent exactement la même pièce (même couleur, même matière, même col, mêmes poches, boutons, fermeture, logos et motif), même sous un autre angle ou une autre lumière.
Deux pièces seulement ressemblantes ne sont pas des doublons. Dans le doute, ne regroupe pas.
Réponds uniquement avec le JSON, sans ``` ni texte autour : {"doublons": [[numéros de la même pièce], …]} ; {"doublons": []} s'il n'y en a pas.
