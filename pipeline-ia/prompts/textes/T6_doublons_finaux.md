---
modele: voir config.json (modeles.arbitrage)
entree: une planche de pièces numérotées ; chaque case = photo produit générée (à gauche) + vraie photo (à droite)
sortie: JSON uniquement
variables: {{n}} {{famille}}
---
Chaque case numérotée (1 à {{n}}) montre une pièce de la garde-robe d'une même personne ({{famille}}) : à gauche sa photo produit (une reconstitution), à droite une vraie photo où elle la porte.
Certaines cases sont en double : la même pièce réelle, comptée plusieurs fois parce qu'elle a été photographiée dans des conditions différentes. Trouve-les.
Une même pièce peut paraître différente d'une vraie photo à l'autre : ouverte ou fermée, en plein soleil ou le soir, en entier ou coupée par le cadrage. Ce qui compte, c'est le modèle : couleur, matière et son usure, col, poches, fermeture, bords-côtes, logos, motif.
Si les photos produit sont presque identiques et que les vraies photos sont compatibles, c'est la même pièce : regroupe-les.
Ne regroupe pas deux pièces dont un détail diffère clairement (couleur, col, poches, logo). Pour les pièces basiques sans détail distinctif (t-shirt blanc uni, jean brut), ne regroupe que si c'est évident.
Réponds uniquement avec le JSON, sans ``` ni texte autour : {"doublons": [[numéros de la même pièce], …]} ; {"doublons": []} s'il n'y en a pas.
