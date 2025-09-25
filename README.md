# KERNELOS

Distribution Linux combinant Debian et Arch.

Objectif: offrir une compatibilité Windows étendue et un flux d’installation d’applications .appx/.msix (best‑effort) sous Linux.

## Compatibilité Windows (Wine/Bottles)

Le profil KernelOS inclut des outils permettant d’exécuter des applications Windows classiques et de convertir/installer des paquets AppX/MSIX au mieux de ce qui est possible sous Linux.

Paquets clés ajoutés (profil ArchISO `profiles/kernelos/packages.x86_64`):

- wine-staging, wine-mono, wine-gecko, winetricks, bottles
- cabextract, p7zip, icoutils
- samba, winbind, ntfs-3g
- powershell (ou powershell-bin selon disponibilité)
- msix-packaging (SDK MSIX open‑source)
- libfuse, fuse2

## Outils fournis (scripts)

Les scripts suivants sont intégrés dans l’image (airootfs):

- /usr/local/bin/kernelos-bottle-create
  - Crée un préfixe Wine optimisé (esync/fsync, DXVK/VKD3D via Winetricks, polices de base, locale).
  - Exemple: `kernelos-bottle-create --name jeux --arch win64`
- /usr/local/bin/kernelos-appx
  - Wrapper CLI pour gérer des paquets .appx/.msix (et .appxbundle/.msixbundle):
    - `kernelos-appx install <chemin.appx|msix|bundle>`: extrait le paquet, détecte l’exécutable principal quand c’est possible, crée un préfixe Wine et des lanceurs (.desktop).
    - `kernelos-appx register <dossier_extrait> [--name NOM] [--exe RELPATH]`: enregistre un répertoire déjà extrait.
    - `kernelos-appx unregister <nom> [--purge]`: supprime l’enregistrement, les lanceurs, et optionnellement les données.
    - `kernelos-appx list`: liste les applications enregistrées.

Des fichiers .desktop utilitaires sont fournis dans `/usr/share/applications/`:

- KernelOS AppX/MSIX Installer (CLI)
- KernelOS Créer un préfixe Wine

## Guide « Applications Windows »

Deux approches sont possibles:

1) Bottles (recommandé pour la simplicité)
- Lancez l’application “Bottles” et créez une bouteille (profil Gaming/Applications selon le besoin).
- Installez vos logiciels/jeux comme sur Windows.

2) Préfixe Wine manuel (avec kernelos-bottle-create)
- `kernelos-bottle-create --name monapp --arch win64`
- Pour lancer un programme dans ce préfixe: `~/.local/bin/wine-run-monapp mon.exe`

### Installer des .appx/.msix

- `kernelos-appx install ~/Téléchargements/MonApp.msix`
  - Le script extrait le paquet (7z), tente d’identifier l’exécutable principal (lecture d’AppxManifest.xml avec PowerShell si dispo, sinon heuristiques), crée un préfixe et un lanceur dans le menu.
- Pour un répertoire déjà extrait: `kernelos-appx register ~/apps/MonAppExtrait --name MonApp`
- Lister/supprimer: `kernelos-appx list` puis `kernelos-appx unregister MonApp [--purge]`

Les données et enregistrements sont stockés sous `~/.local/share/kernelos-appx/` et les préfixes sous `~/.local/share/kernelos/wineprefixes/`.

## Limitations / Disclaimer

- Compatibilité .appx/.msix non garantie; de nombreuses Apps UWP pures ne fonctionneront pas (pas de runtime UWP natif, pas d’APIs sandbox UWP, pas d’intégration kernel‑mode).
- Il s’agit d’une conversion/portage best‑effort vers un format exécutable via Wine/Bottles. Certaines applications nécessitent des ajustements manuels.
- Les pilotes ou fonctionnalités nécessitant un mode noyau Windows ne sont pas pris en charge.

## Dépannage courant

- DPI flou ou trop petit: lancez `winecfg` dans le préfixe, onglet “Graphics”, ajustez le DPI; ou utilisez le lanceur `wine-run-NOM` pour ouvrir `winecfg`.
- Polices manquantes: `winetricks -q corefonts cjkfonts fontsmooth=rgb` dans le préfixe.
- Certificats/HTTPS: mettez à jour les certificats du système; dans Wine, `winetricks -q wininet` peut aider selon le logiciel.
- DirectX/Vulkan: si nécessaire, réinstallez `dxvk`/`vkd3d` via `winetricks` dans le préfixe.

## Dépôts et construction

- Les fichiers du profil se trouvent sous `profiles/kernelos/` et l’overlay système sous `airootfs/`.
- L’intégration des paquets peut dépendre des dépôts activés sur la cible. Adaptez si besoin.
