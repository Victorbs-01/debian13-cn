cat > setup-browsers-and-editors.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Repos/keys + instalación de:
# - Brave, Vivaldi, Opera, Google Chrome
# - Visual Studio Code
# - Cursor (deb directo)
#
# Probado para Debian 13 "trixie"

need_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Ejecuta con sudo: sudo $0"; exit 1
  fi
}

pkg_installed() {
  dpkg -s "$1" &>/dev/null
}

install_prereqs() {
  apt-get update -y
  apt-get install -y --no-install-recommends ca-certificates curl gnupg lsb-release apt-transport-https
  install -d -m 0755 /usr/share/keyrings
}

install_brave() {
  if pkg_installed brave-browser; then echo "Brave ya instalado"; return; fi
  echo ">> Brave"
  curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
    > /etc/apt/sources.list.d/brave-browser-release.list
  apt-get update -y
  apt-get install -y brave-browser
}

install_vivaldi() {
  if pkg_installed vivaldi-stable; then echo "Vivaldi ya instalado"; return; fi
  echo ">> Vivaldi"
  curl -fsSLo /usr/share/keyrings/vivaldi-archive-keyring.gpg \
    https://repo.vivaldi.com/archive/linux_signing_key.pub
  echo "deb [signed-by=/usr/share/keyrings/vivaldi-archive-keyring.gpg] https://repo.vivaldi.com/archive/deb/ stable main" \
    > /etc/apt/sources.list.d/vivaldi.list
  apt-get update -y
  apt-get install -y vivaldi-stable
}

install_opera() {
  if pkg_installed opera-stable; then echo "Opera ya instalado"; return; fi
  echo ">> Opera"
  curl -fsSLo /usr/share/keyrings/opera-browser-archive-keyring.gpg \
    https://deb.opera.com/archive.key
  echo "deb [signed-by=/usr/share/keyrings/opera-browser-archive-keyring.gpg] https://deb.opera.com/opera-stable/ stable non-free" \
    > /etc/apt/sources.list.d/opera-stable.list
  apt-get update -y
  apt-get install -y opera-stable
}

install_chrome() {
  if pkg_installed google-chrome-stable; then echo "Google Chrome ya instalado"; return; fi
  echo ">> Google Chrome"
  curl -fsSLo /usr/share/keyrings/google-chrome.gpg https://dl.google.com/linux/linux_signing_key.pub
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list
  apt-get update -y
  apt-get install -y google-chrome-stable
}

install_vscode() {
  if pkg_installed code; then echo "VS Code ya instalado"; return; fi
  echo ">> Visual Studio Code"
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor -o /usr/share/keyrings/packages.microsoft.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list
  apt-get update -y
  apt-get install -y code
}

install_cursor() {
  if command -v cursor >/dev/null 2>&1; then echo "Cursor ya instalado"; return; fi
  echo ">> Cursor"
  tmpdeb="/tmp/cursor.deb"
  curl -L -o "$tmpdeb" https://downloader.cursor.sh/linux/deb
  apt-get install -y "$tmpdeb"
}

summary() {
  echo
  echo "=== Listo ==="
  brave-browser --version || true
  vivaldi --version || true
  opera --version || true
  google-chrome --version || true
  code --version || true
  command -v cursor >/dev/null && echo "cursor: $(cursor --version 2>/dev/null || echo 'instalado')" || true

  echo
  echo "Atajos:"
  echo "  brave-browser &"
  echo "  vivaldi &"
  echo "  opera &"
  echo "  google-chrome &"
  echo "  code &"
  echo "  cursor &"
  echo
  echo "Opcional (otro navegador):"
  echo "  sudo apt install -y chromium"
  echo "  # Firefox ESR ya viene en Debian por defecto (paquete: firefox-esr)"
}

main() {
  need_root
  install_prereqs
  install_brave
  install_vivaldi
  install_opera
  install_chrome
  install_vscode
  install_cursor
  summary
}

main "$@"
EOF

sudo bash ./setup-browsers-and-editors.sh
