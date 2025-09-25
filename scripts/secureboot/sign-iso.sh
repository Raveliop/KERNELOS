#!/usr/bin/env bash
set -euo pipefail

# Signs EFI binaries and kernels inside an Arch ISO output directory using sbsign.
# Requirements: sbsigntools, mtools (for editing efiboot.img), sbctl (optional), openssl
#
# Usage:
#   sign-iso.sh <iso-path> <output-dir>
#
# Behavior:
#  - Generates keys if not provided via env or repo (see generate-keys.sh)
#  - Replaces EFI/BOOT/BOOTx64.EFI with shimx64.efi
#  - Copies mmx64.efi (MokManager)
#  - Signs systemd-bootx64.efi and stores as EFI/BOOT/grubx64.efi (the loader shim expects)
#  - Signs kernels found in common paths (vmlinuz-linux*, *.efi, UKI images)
#  - Injects KERNELOS public cert (.cer) into the EFI system partition for easy enrollment

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <iso-path> <output-dir>" >&2
  exit 1
fi

ISO_PATH="$1"
OUT_DIR="$2"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/../.." && pwd)

mkdir -p "${OUT_DIR}"

# Prepare working dir
WORK_DIR="${OUT_DIR}/_work"
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"

cp -f "${ISO_PATH}" "${WORK_DIR}/input.iso"
ISO_BASENAME=$(basename "${ISO_PATH}")
ISO_STEM="${ISO_BASENAME%.iso}"

# Load/generate keys
# shellcheck disable=SC1091
eval "$(${SCRIPT_DIR}/generate-keys.sh)"

# Extract efiboot.img from ISO
# The ArchISO usually stores it at /EFI/archiso/efiboot.img
mkdir -p "${WORK_DIR}/iso_mount" "${WORK_DIR}/efi"

# Use bsdtar to extract efiboot.img to avoid loop mounts
bsdtar -xf "${WORK_DIR}/input.iso" -C "${WORK_DIR}/efi_extract" EFI/archiso/efiboot.img || true

if [[ ! -f "${WORK_DIR}/efi_extract/EFI/archiso/efiboot.img" ]]; then
  echo "Could not locate EFI/archiso/efiboot.img inside ISO. Proceeding without injecting shim (ISO may still be signed at kernel-level)." >&2
else
  EFIBOOT_IMG="${WORK_DIR}/efi_extract/EFI/archiso/efiboot.img"
  # Copy out efiboot.img to a writable location
  cp -f "${EFIBOOT_IMG}" "${WORK_DIR}/efiboot.img"

  # Prepare mtools config to edit the FAT image without mounting
  MTOOLSRC="${WORK_DIR}/mtools.conf"
  cat >"${MTOOLSRC}" <<EOF
mtools_skip_check=1
mtools_fat_compatibility=1
# Drive e maps to efiboot.img
drive e: file="${WORK_DIR}/efiboot.img"
EOF
  export MTOOLSRC

  # Locate systemd-boot and rename to keep a copy
  # Sign systemd-boot and place it as EFI/BOOT/grubx64.efi (shim default loader name)
  # Also replace BOOTx64.EFI with shimx64.efi and add MokManager as mmx64.efi

  # 1) Copy shim binaries from the build environment into the image
  SHIM_SRC_DIR="/usr/share/shim"
  if [[ -f "${SHIM_SRC_DIR}/x64/shimx64.efi" ]]; then
    mcopy -o -s "${SHIM_SRC_DIR}/x64/shimx64.efi" e::/EFI/BOOT/BOOTx64.EFI
    if [[ -f "${SHIM_SRC_DIR}/x64/mmx64.efi" ]]; then
      mcopy -o -s "${SHIM_SRC_DIR}/x64/mmx64.efi" e::/EFI/BOOT/mmx64.efi
    fi
  elif [[ -f "${SHIM_SRC_DIR}/shimx64.efi" ]]; then
    mcopy -o -s "${SHIM_SRC_DIR}/shimx64.efi" e::/EFI/BOOT/BOOTx64.EFI
    if [[ -f "${SHIM_SRC_DIR}/mmx64.efi" ]]; then
      mcopy -o -s "${SHIM_SRC_DIR}/mmx64.efi" e::/EFI/BOOT/mmx64.efi
    fi
  else
    echo "shimx64.efi not found in ${SHIM_SRC_DIR}. Skipping shim integration." >&2
  fi

  # 2) Extract existing BOOTx64.EFI (systemd-boot) to sign it, then put it back as grubx64.efi
  TMP_EFI="${WORK_DIR}/BOOTx64.efi"
  mcopy -o e::/EFI/BOOT/BOOTx64.EFI "${TMP_EFI}" || true
  if [[ -s "${TMP_EFI}" ]]; then
    # If we already replaced BOOTx64 with shim, try to read the original systemd-boot path
    # ArchISO typically also stores systemd-boot at /EFI/systemd/systemd-bootx64.efi
    if ! sbverify --list "${TMP_EFI}" >/dev/null 2>&1; then
      mcopy -o e::/EFI/systemd/systemd-bootx64.efi "${TMP_EFI}" || true
    fi
  fi
  if [[ -s "${TMP_EFI}" ]]; then
    sbsign --key "${SB_KEY}" --cert "${SB_CERT}" --output "${TMP_EFI}.signed" "${TMP_EFI}"
    mcopy -o "${TMP_EFI}.signed" e::/EFI/BOOT/grubx64.efi
  else
    echo "Could not locate systemd-boot to sign. Continuing." >&2
  fi

  # 3) Add the public cert for easy MOK enrollment
  mmd -i "${WORK_DIR}/efiboot.img" ::/EFI/KERNELOS 2>/dev/null || true
  mcopy -o "${SB_CERT_DER}" e::/EFI/KERNELOS/KERNELOS-MOK.cer

  # 4) Write the modified efiboot.img back into a copy of the ISO tree and rebuild ISO
  mkdir -p "${WORK_DIR}/iso_tree"
  bsdtar -xf "${WORK_DIR}/input.iso" -C "${WORK_DIR}/iso_tree"
  cp -f "${WORK_DIR}/efiboot.img" "${WORK_DIR}/iso_tree/EFI/archiso/efiboot.img"

  # Include KERNELOS helper and public cert for installed system
  mkdir -p "${WORK_DIR}/iso_tree/KERNELOS"
  cp -f "${ROOT_DIR}/assets/installed/kerneolos-secureboot-setup.sh" "${WORK_DIR}/iso_tree/KERNELOS/kerneolos-secureboot-setup.sh" || true
  chmod 0755 "${WORK_DIR}/iso_tree/KERNELOS/kerneolos-secureboot-setup.sh" || true
  cp -f "${SB_CERT_DER}" "${WORK_DIR}/iso_tree/KERNELOS/KERNELOS-MOK.cer" || true
  cat >"${WORK_DIR}/iso_tree/KERNELOS/README.txt" <<'KRD'
Ce dossier contient:
- KERNELOS-MOK.cer: certificat public à enregistrer via MOK pour démarrer et signer les mises à jour
- kerneolos-secureboot-setup.sh: script post-installation pour configurer Secure Boot sur le système installé
KRD

  # 5) Repack the ISO preserving boot attributes using xorriso
  OUT_ISO="${OUT_DIR}/${ISO_STEM}-secureboot.iso"
  xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames \
    -volid "${ISO_STEM}" -eltorito-boot isolinux/isolinux.bin -no-emul-boot \
    -boot-load-size 4 -boot-info-table -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-catalog isolinux/boot.cat -eltorito-alt-boot \
    -e EFI/archiso/efiboot.img -no-emul-boot -isohybrid-gpt-basdat \
    -o "${OUT_ISO}" "${WORK_DIR}/iso_tree"

  ISO_SIGN_TARGET="${OUT_ISO}"
else
  echo "Skipping shim injection; copying original ISO as output." >&2
  cp -f "${WORK_DIR}/input.iso" "${OUT_DIR}/${ISO_STEM}-unsigned.iso"
  ISO_SIGN_TARGET="${OUT_DIR}/${ISO_STEM}-unsigned.iso"
fi

# Sign likely kernel locations inside ISO tree as well as in EFI image
# Note: For Secure Boot, the firmware validates EFI binaries (shim, loaders, UKI). The raw kernel
# may not be validated unless booted as EFI stub or UKI. We sign when possible to improve coverage.

find_and_sign() {
  local path="$1"
  if [[ -f "${path}" ]]; then
    echo "Signing ${path}" >&2
    sbsign --key "${SB_KEY}" --cert "${SB_CERT}" --output "${path}.signed" "${path}" || return 0
    mv -f "${path}.signed" "${path}"
  fi
}

# Sign files inside rebuilt ISO tree if present
for p in \
  "${WORK_DIR}/iso_tree/arch/boot/x86_64/vmlinuz-linux" \
  "${WORK_DIR}/iso_tree/arch/boot/x86_64/vmlinuz-linux-zen" \
  "${WORK_DIR}/iso_tree/EFI/archiso/vmlinuz.efi" \
  "${WORK_DIR}/iso_tree/EFI/archiso/vmlinuz-linux.efi"; do
  find_and_sign "$p" || true
done

# Emit artifacts: certificate and instructions
cp -f "${SB_CERT_DER}" "${OUT_DIR}/KERNELOS-MOK.cer"
cat >"${OUT_DIR}/INSTRUCTIONS-SECURE-BOOT-FR.txt" <<'EOT'
KERNELOS — Démarrage UEFI Secure Boot (MOK)

1) Dans le firmware, activer UEFI et Secure Boot.
2) Démarrer sur l’ISO KERNELOS. L’écran MOK (MokManager) peut apparaître s’il ne trouve pas la clé.
3) Choisir: Enroll key from disk → Parcourir l’ESP → EFI/KERNELOS/KERNELOS-MOK.cer → Continuer → Confirm → Reboot.
4) Le second démarrage vérifie shim → charge le chargeur signé → charge le kernel signé.
5) Une fois le système installé, exécuter: sudo /usr/local/bin/kerneolos-secureboot-setup pour régler les clés et les hooks.

Remplacement des clés éphémères par clés officielles:
- Fournir keys/secureboot/MOK.key et MOK.crt dans le dépôt (ou secrets de CI SB_PRIVATE_KEY/SB_PUBLIC_CERT).
- Rebâtir l’ISO. Les utilisateurs devront ré-enregistrer la nouvelle clé via MOK.
EOT

# Checksums
( cd "${OUT_DIR}" && sha256sum *.iso > SHA256SUMS )

echo "Output prepared under: ${OUT_DIR}" >&2
