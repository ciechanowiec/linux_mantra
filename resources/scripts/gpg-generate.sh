#!/bin/bash

echo "[INFO] Deleting all old keys"
gpg --delete-secret-and-public-keys "$(gpg --list-keys --with-colons | awk -F: '/^pub/{print $5}')"

echo "[INFO] Generating a new key"
gpg --gen-key

echo "[INFO] All existing keys:"
gpg --list-keys

echo "[INFO] Extracting the singular key"
key_id=$(gpg --list-keys --with-colons | awk -F: '/^pub/{print $5}')

echo "[INFO] The singular key ID: $key_id"

echo "[INFO] Distributing the key to the server"
gpg --keyserver keyserver.ubuntu.com --send-keys "$key_id"

echo "[INFO] Retrieving the key from the server"
gpg --keyserver keyserver.ubuntu.com --recv-keys "$key_id"
