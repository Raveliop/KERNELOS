# KERNELOS
Distribution linux combinant Debian et Arch

## Secure Boot (UEFI)

Objectif: Supporter UEFI Secure Boot out‑of‑the‑box pour l’ISO et le système installé.

Résumé de l’implémentation:
- ISO inclut les outils et chargeurs requis: shim-signed, systemd-boot, sbctl, sbsigntools, mokutil.
- La chaîne de démarrage est signée lors de la construction: systemd-boot et kernel (linux-zen si présent). shim (signé Microsoft) est injecté comme BOOTx64.EFI. La clé publique KERNELOS est copiée dans l’ESP pour l’enregistrement MOK.
- Clés: si des clés officielles KERNELOS sont fournies, elles sont utilisées; sinon, des clés éphémères sont générées pour démonstration.
- Système installé: script post-install fourni pour générer/enregistrer les clés et installer un hook pacman afin de signer automatiquement kernel/UKI après mise à jour.
- CI/CD: un workflow construit l’ISO, signe la chaîne de boot et publie l’ISO, le certificat public et les instructions.

### Démarrage avec Secure Boot (MOK)
1) Activer UEFI + Secure Boot dans le firmware.
2) Démarrer sur l’ISO KERNELOS. Au premier boot, si la clé n’est pas déjà inscrite, MokManager (MOK) s’affiche.
3) Choisir «Enroll key from disk» → parcourir l’ESP → EFI/KERNELOS/KERNELOS-MOK.cer → Continuer → Confirm → Reboot.
4) Au redémarrage: shim (signé Microsoft) valide le chargeur signé, qui charge le kernel signé.

Le fichier `KERNELOS-MOK.cer` est aussi disponible à la racine de l’ISO dans `KERNELOS/`.

### Système installé (post-install)
Sur le système installé, exécuter en root:
```
/KERNELOS/kerneolos-secureboot-setup.sh
```
Ce script:
- Installe sbctl, sbsigntools et mokutil si nécessaire.
- Génère des clés machine si aucune clé officielle KERNELOS n’est fournie (stockées dans `/etc/secureboot/keys/KERNELOS/`).
- Programme l’enregistrement MOK au prochain reboot (via mokutil) pour faire approuver la clé publique.
- Ajoute un hook pacman (`/etc/pacman.d/hooks/99-secureboot-sign.hook`) qui signe automatiquement les kernels/UKI après chaque mise à jour.

Notes:
- Si vous utilisez systemd-boot + UKI, les images EFI (*UKI*) de `/boot/EFI/Linux/*.efi` seront signées.
- Si vous utilisez un kernel classique (`/boot/vmlinuz*`), ce binaire sera signé pour l’amorçage via EFI stub.

### Clés officielles vs clés éphémères
- Clés officielles: placez `keys/secureboot/MOK.key` et `keys/secureboot/MOK.crt` dans le dépôt (non versionné recommandé) ou fournissez-les à la CI via secrets:
  - `SB_PRIVATE_KEY` (base64 du .key)
  - `SB_PUBLIC_CERT` (base64 du .crt)
- Sans clés officielles, l’ISO est construit avec des clés éphémères (pour démonstration). Les utilisateurs devront enregistrer la nouvelle clé quand vous passerez aux clés officielles.

### Régénérer et signer (développement local)
- Les scripts de signature se trouvent dans `scripts/secureboot/`.
- `generate-keys.sh` produit des clés éphémères dans `./.secureboot-keys/` si non fournies.
- Après construction d’un ISO (mkarchiso), exécuter:
```
bash scripts/secureboot/sign-iso.sh <chemin-vers.iso> out_signed/
```
Les artefacts signés se retrouvent dans `out_signed/` (ISO, SHA256SUMS, KERNELOS-MOK.cer, instructions).

### Révocation / rotation de clé
- Pour remplacer une clé, publiez un nouvel ISO signé avec la nouvelle clé et demandez aux utilisateurs d’«Enroll» la nouvelle clé via MOK.
- Optionnel: révoquer l’ancienne clé dans MokManager: `mokutil --list-enrolled` puis `mokutil --delete` (demande un mot de passe et une confirmation au boot).
- Pensez à re-signer tous les binaires EFI/kernels avec la nouvelle clé et à régénérer les UKI si utilisés.

### CI/CD
Le workflow GitHub Actions `Build ISO (Secure Boot)`:
- Clone le profil ArchISO `releng`.
- Ajoute linux-zen + outils Secure Boot.
- Construit l’ISO avec `mkarchiso`.
- Injecte `shim` en BOOTx64.EFI, signe le chargeur et les kernels, et ajoute le certificat MOK + scripts.
- Publie les artefacts: ISO signé, SHA256SUMS, `KERNELOS-MOK.cer`, instructions FR.

Déclenchement: push sur la branche de travail ou `workflow_dispatch`.
