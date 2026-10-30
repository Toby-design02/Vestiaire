# Vestiaire

App iOS de vestiaire numérique piloté par l'IA. Brief produit : https://claude.ai/artifact/99go77eW95FoZehD4AEhmj

## Lancer l'app

1. Ouvre `Vestiaire.xcodeproj` (double-clic). Xcode s'ouvre.
2. En haut au centre, choisis un simulateur d'iPhone (par exemple « iPhone 16 »).
3. Appuie sur ▶️ (ou `Cmd + R`). Le simulateur démarre et l'app s'ouvre sur l'onboarding.

Pour revoir l'onboarding : onglet Profil → « Revoir l'onboarding ».

## État actuel (MVP sur données d'exemple)

- Onboarding : selfie (simulé), accès Photos, révélation progressive, mini-Wrapped, validation en swipe, invitation.
- Vestiaire, deux vues :
  - Mon dressing : façon e-shop de luxe (pièce du mois, rayons, grille, tri), fiches produit, corrections, ouverture aux offres et échanges, et la cabine d'essayage (« je l'achète ? » : comparaison avec le dressing avant l'achat).
  - Mes outfits : l'agent qui compose une tenue (pièces imposées, météo, occasion, style, « et si j'achetais… » avec description ou photo), et l'historique des tenues proposées.
- Découvrir : tendances (vestiaires à découvrir, tenues du moment), Pour toi (pièces qui compléteraient le dressing, à essayer dans une tenue), seconde main (offres et échanges entre utilisateurs).
- OOTD (façon BeReal, mode nuit) : moment du jour, feed flouté tant qu'on n'a pas posté, Mes amis / Amis d'amis, réactions, et mes souvenirs dans un calendrier (avatar en haut à droite).
- Wrapped : format Spotify Wrapped (story plein écran), avec la direction artistique de la boutique.
- Profil : portefeuille, vestiaire public ou privé, amis, confidentialité.

L'agent de tenues et la cabine utilisent des règles simples en attendant le pipeline IA (`Vestiaire/Data/OutfitAgent.swift`). Seule la tenue complète a une image mise en scène (`outfit-chaise`) ; les autres s'affichent à plat sur fond studio.

## Design

Trois ambiances, une identité (`Vestiaire/DesignSystem/Theme.swift`) :
- boutique (vestiaire, découvrir, fiches, Wrapped) : blanc, noir, serif fin pour les titres, petites capitales espacées, filets ; vermillon et vert sapin en touches ;
- OOTD : nuit, sans serif gras et large, façon BeReal.

Pas de dégradés violets, d'icône « étincelles » ni de cartes arrondies partout : ce sont les marques des interfaces générées par IA.
Tant qu'il n'y a pas de photo produit, chaque pièce est dessinée à plat (`GarmentDrawing.swift`).

Les données sont des exemples (`Vestiaire/Data/SampleData.swift`), identiques à chaque lancement. Les modifications ne sont pas encore sauvegardées.

Pour une vraie photo produit :
1. Détoure-la (fond blanc rendu transparent) : `swift tools/detourer.swift photo.jpg pull.png`
2. Glisse le PNG dans `Vestiaire/Resources/Assets.xcassets` et donne-lui le nom indiqué dans `productImageName` (par exemple `pull-vert-sapin`).

## Organisation

```
Vestiaire/
├── App/            point d'entrée, barre d'onglets
├── Models/         User, Item, Session, WearEvent, Outfit, Post, Stats, FeedPost
├── Data/           WardrobeStore (calculs) + données d'exemple
├── Features/       un dossier par écran
├── DesignSystem/   couleurs, typographies, composants
└── Resources/      images
```

Le contrat avec le pipeline IA est décrit dans [docs/modele-de-donnees.md](docs/modele-de-donnees.md).

## Sauvegarde sur GitHub

Le projet est sur GitHub (dépôt privé `Toby-design02/Vestiaire`). Chaque lundi à 10 h, une tâche programmée de l'app Claude lance `tools/sauvegarde-github.sh`, qui enregistre les modifications et les envoie sur GitHub. Si l'app Claude est fermée à ce moment-là, la sauvegarde se fait à sa prochaine ouverture.

- Sauvegarder tout de suite : `zsh tools/sauvegarde-github.sh`
- Modifier ou arrêter la sauvegarde automatique : dans l'app Claude, section des tâches programmées.
