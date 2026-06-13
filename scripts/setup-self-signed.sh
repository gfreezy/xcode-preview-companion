#!/usr/bin/env bash
#
# Create a temporary keychain holding a freshly generated self-signed
# code-signing certificate, and register it so `codesign` can use it
# non-interactively. Intended for CI runners.
#
# All progress output goes to stderr; the certificate common name (to be used
# as SIGN_IDENTITY) is the ONLY thing printed to stdout, so callers can do:
#
#     SIGN_IDENTITY="$(./scripts/setup-self-signed.sh)"
#
set -euo pipefail

CN="${CERT_CN:-XcodePreviewCompanion Self-Signed}"
KEYCHAIN="${KEYCHAIN:-xpc-signing.keychain-db}"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-$(uuidgen)}"

setup() {
  local work cnf p12pass existing
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN

  # 1. Self-signed certificate with the codeSigning extended key usage.
  cnf="$work/openssl.cnf"
  cat > "$cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $CN
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$work/key.pem" -out "$work/cert.pem" \
    -days 3650 -config "$cnf"

  p12pass="$(uuidgen)"
  openssl pkcs12 -export \
    -inkey "$work/key.pem" -in "$work/cert.pem" \
    -out "$work/cert.p12" -passout "pass:$p12pass"

  # 2. Dedicated keychain, imported identity, no-UI access for codesign.
  security delete-keychain "$KEYCHAIN" 2>/dev/null || true
  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  security set-keychain-settings -lut 21600 "$KEYCHAIN"
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  security import "$work/cert.p12" -k "$KEYCHAIN" -P "$p12pass" \
    -T /usr/bin/codesign -T /usr/bin/security
  security set-key-partition-list \
    -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null

  # 3. Add to the user search list while preserving the existing keychains.
  existing="$(security list-keychains -d user | sed -e 's/^[[:space:]]*//' -e 's/"//g')"
  # shellcheck disable=SC2086
  security list-keychains -d user -s "$KEYCHAIN" $existing

  echo "Created self-signed identity '$CN' in keychain '$KEYCHAIN'" >&2
}

setup >&2
echo "$CN"
