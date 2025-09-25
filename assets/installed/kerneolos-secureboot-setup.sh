#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root" >&2
  exit 1
fi

PKGS=(sbctl sbsigntools mokutil)

if command -v pacman >/dev/null 2>&1; then
  pacman -Sy --needed --noconfirm "${PKGS[@]}"
fi

KEY_DIR="/etc/secureboot/keys/KERNELOS"
mkdir -p "${KEY_DIR}"

if [[ -f "${KEY_DIR}/MOK.key" && -f "${KEY_DIR}/MOK.crt" ]]; then
  echo "Using existing keys in ${KEY_DIR}"
else
  echo "Generating machine keys in ${KEY_DIR}"
  openssl req -new -x509 -newkey rsa:4096 -sha256 -keyout "${KEY_DIR}/MOK.key" -out "${KEY_DIR}/MOK.crt" \
    -days 3650 -nodes -subj "/CN=KERNELOS Machine Key/"
  openssl x509 -in "${KEY_DIR}/MOK.crt" -outform DER -out "${KEY_DIR}/MOK.cer"
  chmod 600 "${KEY_DIR}/MOK.key"
fi

SB_KEY="${KEY_DIR}/MOK.key"
SB_CERT="${KEY_DIR}/MOK.crt"
SB_CERT_DER="${KEY_DIR}/MOK.cer"

# Offer to stage MOK enrollment so shim will trust our signatures
if command -v mokutil >/dev/null 2>&1; then
  if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
    echo "Staging MOK enrollment (requires reboot + physical confirmation)"
    set +e
    mokutil --import "${SB_CERT_DER}"
    RES=$?
    set -e
    if [[ ${RES} -ne 0 ]]; then
      echo "mokutil enrollment staging failed or skipped. You can run: mokutil --import ${SB_CERT_DER}" >&2
    fi
  fi
fi

# Install pacman hook to sign kernel/UKIs after updates
mkdir -p /etc/pacman.d/hooks /usr/local/bin
cat >/usr/local/bin/kerneolos-sign-kernel <<EOS
#!/usr/bin/env bash
set -euo pipefail
KEY="${SB_KEY}"
CRT="${SB_CERT}"
shopt -s nullglob
declare -a targets=(
  /boot/EFI/Linux/*.efi
  /boot/vmlinuz*
)
for f in "${targets[@]}"; do
  if [[ -f "$f" ]]; then
    echo "[kerneolos] Signing $f"
    sbsign --key "$KEY" --cert "$CRT" --output "$f.signed" "$f" || continue
    mv -f "$f.signed" "$f"
  fi
done
EOS
chmod +x /usr/local/bin/kerneolos-sign-kernel

cat >/etc/pacman.d/hooks/99-secureboot-sign.hook <<'EOH'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Path
Target = boot/*
Target = usr/lib/modules/*/vmlinuz
Target = usr/lib/kernel/*

[Action]
Description = Signer kernel/UKI pour Secure Boot...
When = PostTransaction
Exec = /usr/local/bin/kerneolos-sign-kernel
NeedsTargets
EOH

# Initial signing pass
/usr/local/bin/kerneolos-sign-kernel || true

echo "KERNELOS Secure Boot setup completed. Reboot to enroll the MOK if requested."
