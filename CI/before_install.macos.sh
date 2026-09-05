#!/bin/bash -e

DEPS_DIR="/tmp"

source ./CI/macos/deps_versions.sh

brew tap --repair
brew update --quiet

# Homebrew stopped bottling for macOS on Intel in 2026, so `brew install` there
# rebuilds curl and its openssl dependency from source -- fifteen minutes, and
# it fails outright when openssl's post-install step trips. Both formulae ship
# on the runner images already, so only install what is actually missing.
for formula in curl p7zip; do
    brew list --versions "$formula" >/dev/null 2>&1 || brew install "$formula"
done

if [[ "${MACOS_AMD64}" ]]; then
    VCPKG_FILE="vcpkg-x64-osx-dynamic"
    command -v /usr/local/bin/brew || arch -x86_64 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    arch -x86_64 bash -c "command -v qmake >/dev/null 2>&1 && qmake -v | grep -F 'Using Qt version 6.' >/dev/null || /usr/local/bin/brew install qt@6"
else
    VCPKG_FILE="vcpkg-arm64-osx-dynamic"

    command -v qmake >/dev/null 2>&1 && qmake -v | grep -F "Using Qt version 6." >/dev/null || brew install qt@6
fi

curl "https://gitlab.com/OpenMW/openmw-deps/-/raw/main/macos/${VCPKG_FILE}-${VCPKG_TAG}-manifest.txt" -o $DEPS_DIR/openmw-manifest.txt

{ read -r URL && read -r HASH FILE; } < $DEPS_DIR/openmw-manifest.txt

curl -fSL -R -J $URL -o $DEPS_DIR/$FILE
echo "${HASH:?}  ${FILE:?}" | sha512sum
7z x -y -o$DEPS_DIR/openmw-deps-pre $DEPS_DIR/$FILE && \
    mv $DEPS_DIR/openmw-deps-pre/*/ $DEPS_DIR/openmw-deps/ && \
    rmdir $DEPS_DIR/openmw-deps-pre

command -v cmake >/dev/null 2>&1 || brew install cmake
