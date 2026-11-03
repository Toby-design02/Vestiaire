# Vestiaire

App iOS de vestiaire numérique piloté par l'IA. Brief produit : https://claude.ai/artifact/99go77eW95FoZehD4AEhmj

## Lancer l'app

1. Ouvre `Vestiaire.xcodeproj` (double-clic). Xcode s'ouvre.
2. En haut au centre, choisis un simulateur d'iPhone (par exemple « iPhone 16 »).
3. Appuie sur ▶️ (ou `Cmd + R`). Le simulateur démarre et l'app s'ouvre sur l'onboarding.

Pour revoir l'onboarding : onglet Profil → « Revoir l'onboarding ».

## État actuel : prototype local sur données d'exemple

Tout est en mémoire et recréé à chaque lancement : rien n'est sauvegardé ni synchronisé. Aucune IA, aucune météo réelle et aucun service web ne sont branchés. Les données d'exemple portent l'étiquette « Exemple » dans le journal, l'agenda et les envies, et les statistiques signalent quand une période en contient.

Quatre onglets : Vestiaire, Découvrir, Wrapped, Profil.

- Onboarding : selfie (simulé), accès Photos, révélation progressive, mini-Wrapped, validation en swipe, invitation.
- Vestiaire, deux vues :
  - Mon dressing : façon e-shop de luxe (pièce du mois, rayons, grille, tri), fiches produit, corrections, ouverture aux offres et échanges, et la cabine d'essayage (« je l'achète ? » : comparaison avec le dressing, puis « Ajouter à mes envies »). Une barre d'outils donne accès à :
    - Filtres : rayon, couleur, saison, occasion, matière, favoris et étiquettes, combinables et effaçables ;
    - Mes envies : liste privée des articles envisagés (saisie manuelle, cabine ou Découvrir), reliés aux pièces semblables du dressing, « Je l'ai acheté » pour les ajouter au dressing ;
    - Statistiques : tableau de bord par période (pièces actives, plus et moins portées, tenues portées par période, couleurs, coût par port) ;
    - Archives : pièces et tenues rangées de côté, restaurables.
  - Mes outfits, trois parties :
    - Tenues : l'agent qui compose une tenue (pièces imposées, météo d'exemple, occasion, style, « et si j'achetais… ») et l'historique des tenues proposées. Depuis une tenue : « Marquer comme portée », « Planifier », « Archiver » ;
    - Journal : le journal privé des tenues portées, en liste ou en calendrier, avec photo, date, contexte et pièces modifiables. C'est la seule source des statistiques et du Wrapped ;
    - Agenda : calendrier des tenues planifiées et des jours sans tenue, événements (nom, début, fin) et voyages avec leur valise (tenues par jour, pièces à emporter sans doublon, cases à cocher, ajouts manuels, pièces manquantes signalées, voyages passés consultables).
- Découvrir : tendances (vestiaires à découvrir, tenues du moment), Pour toi (pièces qui compléteraient le dressing, à essayer dans une tenue ou à ajouter à ses envies), seconde main (offres et échanges entre utilisateurs).
- Wrapped : format Spotify Wrapped (story plein écran), calculé à partir du journal.
- Profil : portefeuille, vestiaire public ou privé, amis, confidentialité.

Une tenue proposée ou planifiée ne compte jamais comme portée tant que l'utilisateur n'a pas touché « Marquer comme portée ». Il n'y a plus de fil social OOTD : pas de publication, de réactions ni d'audience.

L'agent de tenues et la cabine utilisent des règles simples en attendant le pipeline IA (`Vestiaire/Data/OutfitAgent.swift`). Seule la tenue complète a une image mise en scène (`outfit-chaise`) ; les autres s'affichent à plat sur fond studio.

## Design

Une identité (`Vestiaire/DesignSystem/Theme.swift`) : la boutique (vestiaire, tenues, journal, agenda, découvrir, fiches, Wrapped). Blanc, noir, serif fin pour les titres, petites capitales espacées, filets ; vermillon et vert sapin en touches.

Pas de dégradés violets, d'icône « étincelles » ni de cartes arrondies partout : ce sont les marques des interfaces générées par IA.
Tant qu'il n'y a pas de photo produit, chaque pièce est dessinée à plat (`GarmentDrawing.swift`).

Les données sont des exemples (`Vestiaire/Data/SampleData.swift`), identiques à chaque lancement. Les modifications (journal, agenda, envies, étiquettes, archives) ne sont pas encore sauvegardées.

Pour une vraie photo produit :
1. Détoure-la (fond blanc rendu transparent) : `swift tools/detourer.swift photo.jpg pull.png`
2. Glisse le PNG dans `Vestiaire/Resources/Assets.xcassets` et donne-lui le nom indiqué dans `productImageName` (par exemple `pull-vert-sapin`).

## Organisation

```
Vestiaire/
├── App/            point d'entrée, barre d'onglets
├── Models/         Item, Session + WearEvent (journal), GeneratedOutfit, Planning, Wish, filtres, Stats
├── Data/           WardrobeStore (calculs, journal), agenda, valise et envies, données d'exemple
├── Features/       un dossier par écran
├── DesignSystem/   couleurs, typographies, composants
└── Resources/      images
```

Le contrat avec le pipeline IA est décrit dans [docs/modele-de-donnees.md](docs/modele-de-donnees.md).

## Sauvegarde sur GitHub

Le projet est sur GitHub (dépôt privé `Toby-design02/Vestiaire`). Chaque lundi à 10 h, une tâche programmée de l'app Claude lance `tools/sauvegarde-github.sh`, qui enregistre les modifications et les envoie sur GitHub. Si l'app Claude est fermée à ce moment-là, la sauvegarde se fait à sa prochaine ouverture.

- Sauvegarder tout de suite : `zsh tools/sauvegarde-github.sh`
- Modifier ou arrêter la sauvegarde automatique : dans l'app Claude, section des tâches programmées.
