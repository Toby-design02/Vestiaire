---
modele: voir config.json (modeles.arbitrage)
entree: une planche : la photo 1 est une vue partielle d'une pièce, les photos 2 et suivantes sont des pièces déjà connues
sortie: JSON uniquement
variables: {{n}} {{famille}}
---
La photo 1 montre une partie d'un vêtement ({{famille}}), souvent en gros plan ou partiellement cachée. Les photos 2 à {{n}} montrent des pièces de la garde-robe de la même personne.
La photo 1 est-elle l'une de ces pièces ? Compare la couleur, la matière, le col, les coutures, les boutons, la fermeture, les logos et le motif visibles.
Réponds avec le numéro de la pièce seulement si tu en es sûr ; sinon 0.
Réponds uniquement avec le JSON, sans ``` ni texte autour : {"piece": numéro ou 0}
