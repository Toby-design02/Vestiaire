# Modèle de données : contrat app ↔ pipeline IA

Noms des champs côté code (anglais) et leur sens dans le brief. À valider avec la discussion du pipeline avant de brancher Supabase.

**État actuel : prototype local.** Tout est gardé en mémoire dans `WardrobeStore` et recréé à chaque lancement à partir de `Data/SampleData.swift`. Rien n'est sauvegardé ni synchronisé. Aucune IA, aucune météo réelle, aucun service web n'est branché. Les données d'exemple portent `isSample = true` et s'affichent avec l'étiquette « Exemple ».

## Item (pièce) — `Models/Item.swift`

| Champ | Brief | Type |
|---|---|---|
| `category` | rayon | `outerwear`, `knitwear`, `baseLayer`, `bottoms`, `shoes`, `accessories` |
| `type` | type | texte (« Pull col rond ») |
| `colors`, `colorHex` | couleurs | liste de noms + couleur principale en hexadécimal |
| `pattern`, `material`, `fit`, `collar` | motif, matière, coupe, col | texte facultatif |
| `frontDetails`, `backDetails` | détails face et dos | texte facultatif |
| `detectedTexts` | logos et textes lus | liste |
| `brand.name`, `brand.model`, `brand.confidence`, `brand.source` | marque + modèle, confiance, source | source : `photo`, `web`, `user` |
| `pricePaid`, `priceNew`, `resaleValue` | prix payé, prix neuf, valeur de revente | euros |
| `status` | statut | `active`, `archived`, `sold`, `donated` |
| `productImageName` | photo produit générée | nom ou URL de l'image |
| `sourcePhotos` | photos sources par angle | `angle` (`front`, `back`, `side`) + identifiant de la photo sur l'iPhone |
| `openToOffers`, `openToSwap` | seconde main | booléens |
| `isFavorite` | favori | booléen, saisi par l'utilisateur |
| `seasons` | saisons | `spring`, `summer`, `autumn`, `winter` ; vide tant que non renseigné |
| `occasions` | occasions | `everyday`, `work`, `evening`, `weekend` ; vide tant que non renseigné |
| `tagIDs` | étiquettes personnelles | identifiants de `ItemTag` |

Statuts :
- `active` : dans le dressing, proposée par l'agent de tenues ;
- `archived` : rangée de côté (hors saison, à retoucher…). Hors du dressing actif et des tenues proposées, restaurable, historique de port conservé ;
- `sold`, `donated` : sortie du vestiaire, historique conservé ;
- « Ce n'est pas à moi » supprime la pièce et ses ports.

## ItemTag — `Models/Item.swift`

`name`. Étiquettes créées, renommées et supprimées par l'utilisateur. Supprimer une étiquette la retire de toutes les pièces.

## Journal des tenues portées : Session + WearEvent — `Models/Activity.swift`

Le journal est privé : il n'est jamais publié ni partagé. C'est **la seule source** des ports, des statistiques et du Wrapped.

**Session** (une tenue portée) : `date`, `place` (lieu approximatif), `context` (`everyday`, `work`, `evening`, `travel`, `beach`, `sport`), `photoCount`, `origin`, `photo`, `samplePhotoName`, `outfitID`, `isSample`.

- `origin` : `gallery` (retrouvée par le pipeline dans les photos de la galerie) ou `journal` (enregistrée à la main) ;
- `photo` : photo personnelle facultative, qui reste sur l'iPhone ;
- `samplePhotoName` : photo d'exemple livrée avec l'app (prototype uniquement) ;
- `outfitID` : la tenue proposée (`GeneratedOutfit`) que l'utilisateur a marquée comme portée.

**WearEvent** : `itemID`, `sessionID`, `date`. Une ligne par pièce portée dans une session. Corriger les pièces d'une entrée remplace ses `WearEvent`.

Une tenue proposée ou planifiée ne crée jamais de `Session` toute seule : il faut toucher « Marquer comme portée ».

## GeneratedOutfit (tenue proposée) — `Models/Outfits.swift`

`date`, `itemIDs`, `tryOn` (pièce pas encore achetée, essayée virtuellement), `occasion`, `style`, `weather`, `renderName`, `reasons`, `isArchived`.

Une tenue archivée sort de l'historique « Tenues proposées » mais reste restaurable depuis les Archives. Archiver une tenue n'a aucun effet sur le journal.

## Agenda — `Models/Planning.swift`

**WardrobeEvent** : `name`, `kind` (`general` ou `travel`), `start`, `end`, `place`, `isSample`.

**PlannedOutfit** : `date`, `itemIDs`, `outfitID` (tenue proposée d'origine), `eventID`, `note`, `wornSessionID` (l'entrée du journal créée quand la tenue a été marquée comme portée), `isSample`.

**PackingList** (valise d'un voyage) : `eventID`, `packedItemIDs` (pièces cochées), `extras` (`PackingExtra` : `name`, `isPacked`).

La liste des pièces à emporter n'est pas stockée : elle est calculée à partir des tenues planifiées pendant le voyage, sans doublon. Les pièces manquantes (archivées, vendues, ou essayées virtuellement mais pas achetées) sont signalées, jamais ajoutées automatiquement.

## Wish (liste d'envies) — `Models/Wishlist.swift`

`description`, `category`, `colorName`, `colorHex`, `brand`, `estimatedPrice`, `url`, `photo`, `addedAt`, `source` (`fittingRoom`, `discover`, `manual`), `similarItemIDs`, `purchasedItemID`, `isSample`.

Le rayon et la couleur sont lus dans la description (`PieceDescription`). `similarItemIDs` relie l'article aux pièces semblables du dressing (même rayon, couleur proche), calculé à l'ajout et à chaque modification. L'URL est saisie à la main : aucune information n'est récupérée sur le web. « Je l'ai acheté » crée une pièce active dans le dressing.

## Découvrir — `Models/Discover.swift`

`ProfileAuthor`, `DiscoverProfile`, `TrendingOutfit`, `Listing`, `Recommendation` : données d'exemple. Aucun réseau social n'est branché.

## User — `Models/User.swift`

`displayName`, `isWardrobePublic`, `friendIDs`. Le selfie de référence n'est jamais synchronisé.

## Calculs — `Data/WardrobeStore.swift`

- **Jours enregistrés** = jours avec au moins une tenue portée dans le journal.
- **Taux de port** = jours où la pièce est portée ÷ jours enregistrés.
- **Coût par port** = prix payé ÷ jours portés (depuis le début).
- **Pièce dormante** = pas portée depuis 90 jours.
- **Stats** (`stats(for:)`) : calculées à la volée par période, pas stockées. Un seul calcul sert au Wrapped et au tableau de bord : pièces actives, tenues portées, pièces les plus et les moins portées, couleurs portées, coût par port, et un indicateur `includesSampleData`.
- Les pièces archivées, vendues ou données sont exclues des classements, mais leurs ports restent dans le journal.

## Supprimé

Le fil social OOTD (`FeedPost`, `Reaction`, `FeedCircle`, `Post`, `Audience`) et le type `Outfit` (remplacé par `Session` + `WearEvent` pour les tenues portées et `GeneratedOutfit` pour les tenues proposées).
