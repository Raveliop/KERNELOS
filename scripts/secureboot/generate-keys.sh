#!/usr/bin/env bash
set -euo pipefail

# Generates ephemeral Secure Boot signing keys if none are provided via env vars or repo files.
# Outputs:
#   SB_KEY: path to private key (PEM)
#   SB_CERT: path to public certificate (X.509 .crt)
#   SB_CERT_DER: path to public certificate (DER .cer) — for MOK enrollment
#
# If the repository provides official keys at keys/secureboot/MOK.key and MOK.crt, they will be used.
# Otherwise, ephemeral keys are generated under ./.secureboot-keys.

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
KEYS_DIR_REPO="${ROOT_DIR}/keys/secureboot"
KEYS_DIR_LOCAL="${ROOT_DIR}/.secureboot-keys"

mkdir -p "${KEYS_DIR_LOCAL}"

if [[ -f "${KEYS_DIR_REPO}/MOK.key" && -f "${KEYS_DIR_REPO}/MOK.crt" ]]; then
  SB_KEY="${KEYS_DIR_REPO}/MOK.key"
  SB_CERT="${KEYS_DIR_REPO}/MOK.crt"
  echo "Using project-provided Secure Boot keys at ${KEYS_DIR_REPO}" >&2
else
  SB_KEY="${KEYS_DIR_LOCAL}/MOK.key"
  SB_CERT="${KEYS_DIR_LOCAL}/MOK.crt"
  SB_SUBJ="/CN=KERNELOS Secure Boot (ephemeral)/O=KERNELOS"
  if [[ ! -f "${SB_KEY}" || ! -f "${SB_CERT}" ]]; then
    echo "Generating ephemeral Secure Boot keys under ${KEYS_DIR_LOCAL} ..." >&2
    # RSA 4096 for broad compatibility with shim
    openssl req -new -x509 -newkey rsa:4096 -sha256 -keyout "${SB_KEY}" -out "${SB_CERT}" \
      -days 3650 -nodes -subj "${SB_SUBJ}"
    chmod 600 "${SB_KEY}"
  else
    echo "Ephemeral keys already exist in ${KEYS_DIR_LOCAL}" >&2
  fi
fi

# Export DER format for MOK enrollment
SB_CERT_DER="${SB_CERT%.crt}.cer"
opera_cmd() { :; }
if [[ ! -f "${SB_CERT_DER}" || "${SB_CERT_DER}" -ot "${SB_CERT}" ]]; then
  openssl x509 -in "${SB_CERT}" -outform DER -out "${SB_CERT_DER}"
fi

# Print exports for caller scripts
cat <<EOF
SB_KEY=${SB_KEY}
SB_CERT=${SB_CERT}
SB_CERT_DER=${SB_CERT_DER}
EOF
