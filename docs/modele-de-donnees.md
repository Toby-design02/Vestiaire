# Modèle de données : contrat app ↔ pipeline IA

Noms des champs côté code (anglais) et leur sens dans le brief. À valider avec la discussion du pipeline avant de brancher Supabase.

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
| `status` | statut | `active`, `sold`, `donated` |
| `productImageName` | photo produit générée | nom ou URL de l'image |
| `sourcePhotos` | photos sources par angle | `angle` (`front`, `back`, `side`) + identifiant de la photo sur l'iPhone |

## Session — `Models/Activity.swift`

`date`, `place` (lieu approximatif), `context` (`everyday`, `work`, `evening`, `travel`, `beach`, `sport`), `photoCount`.

## WearEvent

`itemID`, `sessionID`, `date`. Une ligne par pièce visible dans une séance.

## Outfit

`itemIDs`, `date`, `source` (`photo`, `ootd`, `agent`), `flatImageName` (tenue générée à plat).

## Post (OOTD)

`outfitID`, `authorID`, `audience` (`friends`, `everyone`), `reactions`.

## User — `Models/User.swift`

`displayName`, `isWardrobePublic`, `friendIDs`. Le selfie de référence n'est jamais synchronisé.

## Calculs — `Data/WardrobeStore.swift`

- **Taux de port** = jours où la pièce est portée ÷ jours où l'utilisateur est en photo.
- **Coût par port** = prix payé ÷ jours portés.
- **Pièce dormante** = pas portée depuis 90 jours.
- **Stats** (Wrapped) : calculées à la volée par période, pas stockées.
