# KERNELOS
Distribution linux combinant Debian et Arch

## Performance & Jeux

Cette configuration ajoute une stack jeux prête à l’emploi avec Steam, Lutris, Gamescope, Gamemode et des optimisations système. Elle cible NVIDIA, AMD et Intel.

### Paquets clés

Officiels:
- steam, steam-native-runtime
- lutris
- mangohud, lib32-mangohud, goverlay
- gamescope, gamemode, lib32-gamemode
- dxvk, vkd3d-proton, wine-mono, wine-gecko
- pipewire, pipewire-pulse, pipewire-alsa, pipewire-jack, wireplumber
- alsa-plugins, lib32-alsa-plugins, lib32-libpulse
- xdg-desktop-portal, xdg-desktop-portal-kde
- mesa, mesa-utils, lib32-mesa
- vulkan-icd-loader, lib32-vulkan-icd-loader
- vulkan-radeon, vulkan-intel, lib32-vulkan-radeon, lib32-vulkan-intel
- nvidia-dkms, nvidia-utils, lib32-nvidia-utils, nvidia-prime

AUR/Flatpak (à installer après installation si souhaité):
- protonup-qt (Proton-GE)
- heroic-games-launcher-bin

Flatpak recommandé:
```
sudo pacman -S flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install -y flathub net.davidotek.pupgui2 flathub com.heroicgameslauncher.hgl
```

### Préconfiguration GPU

Scripts installés dans /usr/local/bin:
- kernelos-gpu-setup: autodétecte le GPU et prépare l’environnement (NVIDIA KMS, RADV_PERFTEST=aco pour AMD) en écrivant /etc/profile.d/kernelos-gpu.sh.
- kernelos-gamemode-wrapper: lance un jeu avec gamemode, gamescope et MangoHud.

Exécuter après installation pour finaliser l’environnement:
```
sudo kernelos-gpu-setup
```

Fichiers de configuration inclus:
- /etc/sysctl.d/99-kernelos-gaming.conf: swappiness bas, inotify élevés, vm.max_map_count=1048576
- /etc/udev/rules.d/60-io-scheduler.rules: BFQ pour HDD, mq-deadline pour SSD SATA, kyber pour NVMe
- /etc/modprobe.d/nvidia.conf: modeset KMS
- /etc/modprobe.d/50-amd.conf: amdgpu dc=1
- /etc/security/limits.d/99-kernelos.conf: nofile/memlock élevés pour ESYNC/FSYNC

### Steam et Proton‑GE

Proton‑GE via ProtonUp‑Qt:
- Flatpak: net.davidotek.pupgui2
- AUR: protonup-qt

Dans Steam: Paramètres → Compatibilité → Forcer une version spécifique de Proton (choisir Proton‑GE une fois installé).

Activer MangoHud dans un jeu Steam:
- Options de lancement: `mangohud %command%`

Activer Gamescope dans un jeu Steam (exemple 1080p/60):
- Options de lancement: `gamemoderun gamescope -f -w 1920 -h 1080 -r 60 -F 60 -- %command%`

### Lutris et Heroic

- Lutris est installé depuis les dépôts officiels.
- Heroic: Flatpak `com.heroicgameslauncher.hgl` recommandé ou AUR `heroic-games-launcher-bin`.

### Wrapper Gamescope/Gamemode

Exemples d’utilisation:
```
kernelos-gamemode-wrapper /chemin/vers/jeu
kernelos-gamemode-wrapper steam -applaunch 123456
```
Variables d’environnement utiles:
- GAMESCOPE_W, GAMESCOPE_H, GAMESCOPE_RR, GAMESCOPE_FPS, GAMESCOPE_OPTS
- MANGOHUD=1 pour afficher l’overlay (activé par défaut dans le wrapper)

Détection GPU:
- NVIDIA: le wrapper utilise prime-run si disponible
- AMD: RADV_PERFTEST=aco appliqué par kernelos-gpu-setup

### Dépannage rapide

- Logs Proton: définir `PROTON_LOG=1` dans les options de lancement; le log est créé dans le dossier du jeu (`steam-<appid>.log`).
- DXVK: `DXVK_LOG_LEVEL=info` ou `DXVK_HUD=1`
- VKD3D: `VKD3D_DEBUG=info`
- ESYNC/FSYNC: les limites de fichiers sont relevées via PAM. Si votre session systemd n’hérite pas, configurez aussi `DefaultLimitNOFILE` côté systemd utilisateur.
- NVIDIA: assurez-vous que `nvidia_drm.modeset=1` est actif et utilisez `prime-run` sur machines hybrides.
