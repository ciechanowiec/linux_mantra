#!/bin/bash

echo "[INFO] Disabling IPv6 for dirmngr"
DIRMNGR_CONF="${HOME}/.gnupg/dirmngr.conf"
if [[ ! -f "${DIRMNGR_CONF}" ]]; then
  mkdir -p "$(dirname "${DIRMNGR_CONF}")"
  touch "${DIRMNGR_CONF}"
fi
if ! grep -qxF "disable-ipv6" "${DIRMNGR_CONF}"; then
  echo "disable-ipv6" >> "${DIRMNGR_CONF}"
fi
gpgconf --kill dirmngr
sleep 3

echo "[INFO] Deleting all existing keys"
KEY_LISTING=$(gpg --list-keys --with-colons)
EXISTING_KEYS=$(awk -F: '/^pub/ {print $5}' <<< "${KEY_LISTING}")

for KEY in ${EXISTING_KEYS}; do
  gpg --yes --pinentry-mode loopback --delete-secret-and-public-keys "${KEY}"
done

echo "[INFO] Generating a new key"
gpg --gen-key

echo "[INFO] All existing keys:"
gpg --list-keys

echo "[INFO] Getting the newly generated key"
KEY_LISTING=$(gpg --list-keys --with-colons)
NEW_KEY_ID=$(awk -F: '/^pub/{last=$5} END{print last}' <<< "${KEY_LISTING}")

echo "[INFO] The new key ID: ${NEW_KEY_ID}"

echo "[INFO] Distributing the key to the server"
gpg --keyserver keyserver.ubuntu.com --send-keys "${NEW_KEY_ID}"

echo "[INFO] Retrieving the key from the server"
gpg --keyserver keyserver.ubuntu.com --recv-keys "${NEW_KEY_ID}"
