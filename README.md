# KERNELOS
Distribution linux combinant Debian et Arch

## Interface et personnalisation (KDE Plasma 6)

Cette branche ajoute un environnement bureau KDE Plasma 6 (Wayland) préconfiguré pour la session live et l’installation.

- Session par défaut: Plasma (Wayland)
- Thème clair inspiré de la maquette, dock/panel supérieur centré et flottant
- Icônes: Papirus (variante claire)
- Police: Inter
- SDDM: thème "KERNELOS" dédié (pastel), autologin pour l’utilisateur live
- Applications par défaut: Firefox, Dolphin, Konsole, Spectacle, Partition Manager, Discover (+ PackageKit Qt6 + Flatpak)

### Paquets clés
Voir `profiles/kernelos/packages.x86_64`.

### Emplacements des réglages
- SDDM: `profiles/kernelos/airootfs/etc/sddm.conf.d/10-kernelos.conf` et thème dans `usr/share/sddm/themes/kernelos/`
- KDE/Plasma par défaut (système): `profiles/kernelos/airootfs/etc/xdg/` (kdeglobals, kwinrc, plasmarc, kscreenlockerrc, plasma-org.kde.plasma.desktop-appletsrc)
- GTK3: `profiles/kernelos/airootfs/etc/xdg/gtk-3.0/settings.ini`
- Kvantum: `profiles/kernelos/airootfs/etc/xdg/Kvantum/kvantum.kvconfig`
- Fond d’écran: `profiles/kernelos/airootfs/usr/share/backgrounds/kernelos/default.png`
- Script de première connexion: `profiles/kernelos/airootfs/usr/local/bin/kernelos-first-login` (lancé via `etc/xdg/autostart/`)
- Branding (à compléter/remplacer): `branding/wallpaper`, `branding/icons`, `branding/sddm`

### Remplacer le fond d’écran / branding
- Remplacez `profiles/kernelos/airootfs/usr/share/backgrounds/kernelos/default.png` par votre image (1920x1080), ou mettez votre fichier dans `branding/wallpaper/` puis synchronisez dans la recette.
- Le thème SDDM lit l’image depuis `theme.conf` (clé Background). Adapter si nécessaire.

### Rétablir le thème par défaut KDE
Pour réappliquer les valeurs par défaut fournies par KERNELOS sur un profil utilisateur:

1. Fermer la session KDE.
2. Supprimer ou renommer les fichiers de config utilisateur concernés:
   - `~/.config/plasma-org.kde.plasma.desktop-appletsrc`
   - `~/.config/kdeglobals`
   - `~/.config/kwinrc`
3. Se reconnecter: le script `kernelos-first-login` réappliquera la configuration de base si aucun profil utilisateur n’existe pour ces fichiers.

Alternativement, utiliser:
- `plasma-apply-wallpaperimage /usr/share/backgrounds/kernelos/default.png`
- `plasma-apply-colorscheme BreezeLight`

### Passer en session X11 (en cas de souci GPU)
À l’écran de connexion SDDM, cliquez sur l’icône de session et choisissez "Plasma (X11)" au lieu de "Plasma (Wayland)". Le choix est mémorisé pour l’utilisateur.

### Notes
- Latte Dock n’étant plus maintenu sous Plasma 6, l’effet visuel est reproduit avec un panel Plasma flottant et arrondi. Aucune dépendance à Latte n’est requise.
- Les fichiers sous `/etc/xdg` sont génériques et ne dépendent pas d’un UID spécifique.
- Le script de première connexion crée le marqueur `~/.config/.kernelos-first-login-done` pour ne pas réappliquer les réglages à chaque démarrage.

