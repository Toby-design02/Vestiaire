---
modele: voir config.json (modeles.arbitrage)
entree: une planche de photos numérotées (découpes d'une même famille de pièces), la n°1 est la référence
sortie: JSON uniquement
variables: {{n}} {{famille}}
---
Ces {{n}} photos numérotées sont des découpes de vêtements ({{famille}}) portés par la même personne, à des jours différents. La photo 1 est la référence.
Quelles autres photos montrent exactement la même pièce que la photo 1 : même couleur, même matière, même col, mêmes poches, boutons, fermeture, logos et motif ?
Une pièce seulement ressemblante ne compte pas. Dans le doute, ne la cite pas.
Réponds uniquement avec le JSON, sans ``` ni texte autour : {"memes": [numéros des photos]}
