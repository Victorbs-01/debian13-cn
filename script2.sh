rm -f setup-dev13-devstation-v2.sh
cat > setup-dev13-devstation-v2.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "\n==== $* ====\n"; }

need_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Ejecuta con: sudo bash $0"; exit 1
  fi
}

check_codename() {
  local c; c="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  if [[ "$c" != "trixie" && "${FORCE:-0}" != "1" ]]; then
    echo "Este sistema no es trixie (es: $c). Exporta FORCE=1 si deseas continuar."; exit 1
  fi
}

apt_ok() {
  log "apt update (Tsinghua)"
  apt-get update -y
}

install_base() {
  log "Base de utilidades y toolchain"
  apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg lsb-release apt-transport-https \
    git build-essential python3 make gcc g++ unzip \
    arandr x11-xserver-utils
}

install_nvidia() {
  log "NVIDIA driver"
  apt-get install -y firmware-misc-nonfree nvidia-detect || true
  if ! apt-get install -y nvidia-driver; then
    echo "nvidia-driver falló; corre 'nvidia-detect' y usa el paquete legacy sugerido (ej. nvidia-legacy-470xx-driver)."
  fi
}

install_monitoring() {
  log "Monitoreo"
  apt-get install -y htop iotop iftop lm-sensors nvtop || true
  yes | sensors-detect --auto || true
}

install_docker() {
  log "Docker (repo oficial)"
  apt-get remove -y docker docker-engine docker.io containerd runc || true
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  local codename; codename="$(lsb_release -cs)"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${codename} stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  local u="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
  if [[ -n "$u" && "$u" != "root" ]]; then
    usermod -aG docker "$u" || true
    echo "Usuario $u agregado a 'docker' (relogin requerido)."
  fi
}

install_node_volta() {
  log "Volta + Node 24 + pnpm"
  local u="${SUDO_USER:-}"
  if [[ -n "$u" && "$u" != "root" ]]; then
    sudo -u "$u" bash -lc 'curl -fsSL https://get.volta.sh | bash'
    sudo -u "$u" bash -lc '
      source ~/.bashrc 2>/dev/null || true
      export VOLTA_HOME=$HOME/.volta; export PATH=$VOLTA_HOME/bin:$PATH
      volta install node@24 pnpm@latest
      node -v; pnpm -v
    '
  else
    curl -fsSL https://get.volta.sh | bash
    export VOLTA_HOME=/root/.volta; export PATH="$VOLTA_HOME/bin:$PATH"
    volta install node@24 pnpm@latest
    node -v; pnpm -v
  fi
}

summary() {
  log "RESUMEN"
  echo "• NVIDIA:      nvidia-smi (tras reiniciar)"
  echo "• Monitoreo:   htop / iotop / iftop / nvtop / sensors"
  echo "• Docker:      docker --version ; docker run --rm hello-world"
  echo "• Node/PNPM:   node -v ; pnpm -v  (si no aparecen, reabre sesión)"
  echo
  echo "Reinicia para cargar el driver NVIDIA y aplicar el grupo 'docker'."
}

main() {
  need_root
  check_codename
  apt_ok
  install_base
  install_nvidia
  install_monitoring
  install_docker
  install_node_volta
  summary
}
main "$@"
EOF
