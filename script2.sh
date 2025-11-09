cat > setup-dev13-devstation.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# =========================
# Debian 13 "trixie" dev station bootstrap
# - NVIDIA drivers + display utils
# - System monitoring (cpu/ram/net/disk/gpu/temps)
# - Docker Engine + Compose plugin (repo oficial)
# - Volta + Node 24 + pnpm
# - Toolchain para compilar / usar Vendure
# - (Opcional) Postgres + Redis
# =========================

# -------- Config editables --------
INSTALL_DB="${INSTALL_DB:-false}"   # true para instalar postgres + redis
DOCKER_CHANNEL="${DOCKER_CHANNEL:-stable}"  # canal docker apt
NODE_VERSION="${NODE_VERSION:-24}"          # node LTS/actual
PNPM_VERSION="${PNPM_VERSION:-latest}"      # pnpm version para volta
# ----------------------------------

need_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Reejecuta con sudo: sudo $0"; exit 1
  fi
}

check_codename() {
  local codename; codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
  if [[ "${codename}" != "trixie" ]]; then
    echo "ADVERTENCIA: este sistema no es trixie (es: ${codename})."
    echo "Si estás seguro, exporta FORCE=1 y vuelve a ejecutar."
    [[ "${FORCE:-0}" == "1" ]] || exit 1
  fi
}

apt_update_quiet() {
  apt-get update -y
}

install_base() {
  echo ">> Base de utilidades y toolchain…"
  apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg lsb-release apt-transport-https \
    git build-essential python3 make gcc g++ unzip \
    arandr xrandr
}

install_nvidia() {
  echo ">> NVIDIA drivers…"
  apt-get install -y firmware-misc-nonfree nvidia-detect
  # meta-paquete que selecciona driver moderno apropiado
  apt-get install -y nvidia-driver || {
    echo "!! No se pudo instalar nvidia-driver. Si tu GPU es muy antigua, puede requerir legacy."
    echo "   Ejecuta: nvidia-detect  (y luego instala el paquete sugerido)"
  }
}

install_monitoring() {
  echo ">> Monitoreo del sistema…"
  apt-get install -y htop iotop iftop lm-sensors nvtop
  # Autodetect de sensores (no crítico si falla)
  if command -v sensors-detect >/dev/null 2>&1; then
    yes | sensors-detect --auto || true
  fi
}

install_docker() {
  echo ">> Docker Engine (repo oficial)…"
  apt-get remove -y docker docker-engine docker.io containerd runc || true

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  codename="$(lsb_release -cs)"
  echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian ${codename} ${DOCKER_CHANNEL}" \
    > /etc/apt/sources.list.d/docker.list

  apt_update_quiet
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl enable --now docker
  echo ">> Añadiendo usuario al grupo docker…"
  local target_user="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
  if [[ -n "${target_user}" ]]; then
    usermod -aG docker "${target_user}"
    echo "   -> ${target_user} añadido a 'docker'. Cierra y abre sesión para aplicar."
  else
    echo "   (No se detectó SUDO_USER; omitiendo)"
  fi
}

install_volta_node() {
  echo ">> Volta + Node ${NODE_VERSION} + pnpm (${PNPM_VERSION})…"
  # instalar Volta en el usuario real (no root) si es posible
  local target_user="${SUDO_USER:-}"
  if [[ -n "${target_user}" && "${target_user}" != "root" ]]; then
    sudo -u "${target_user}" bash -lc 'curl -fsSL https://get.volta.sh | bash'
    # cargar volta y fijar versiones
    sudo -u "${target_user}" bash -lc "
      source ~/.bashrc 2>/dev/null || true
      export VOLTA_HOME=\$HOME/.volta
      export PATH=\$VOLTA_HOME/bin:\$PATH
      volta install node@${NODE_VERSION} pnpm@${PNPM_VERSION}
      node -v && pnpm -v
    "
  else
    # fallback: instalar en root (no ideal, pero funcional)
    curl -fsSL https://get.volta.sh | bash
    export VOLTA_HOME=/root/.volta
    export PATH="$VOLTA_HOME/bin:$PATH"
    volta install node@${NODE_VERSION} pnpm@${PNPM_VERSION}
    node -v && pnpm -v
  fi
}

install_db_optional() {
  if [[ "${INSTALL_DB}" == "true" ]]; then
    echo ">> Postgres + Redis (opcional)…"
    apt-get install -y postgresql redis-server
    systemctl enable --now postgresql redis-server
  fi
}

summary_next_steps() {
  echo ""
  echo "================= RESUMEN ================="
  echo "- NVIDIA instalado (verifica con: nvidia-smi)"
  echo "- Monitoreo: htop, iotop, iftop, nvtop, lm-sensors"
  echo "- Docker Engine + Compose plugin listos (docker --version)"
  echo "- Volta + Node ${NODE_VERSION} + pnpm listos (node -v, pnpm -v)"
  if [[ "${INSTALL_DB}" == "true" ]]; then
    echo "- Postgres y Redis habilitados"
  else
    echo "- Postgres y Redis (no instalados). Exporta INSTALL_DB=true si los quieres."
  fi
  echo "-------------------------------------------"
  echo "IMPORTANTE:"
  echo " - REINICIA para asegurar carga del driver NVIDIA y grupo 'docker'."
  echo " - Tras reiniciar, prueba:"
  echo "     nvidia-smi"
  echo "     docker run --rm hello-world"
  echo "     node -v && pnpm -v"
  echo "     arandr  (para ajustar resolución, si usas X11)"
  echo "==========================================="
}

main() {
  need_root
  check_codename
  apt_update_quiet
  install_base
  install_nvidia
  install_monitoring
  install_docker
  install_volta_node
  install_db_optional
  summary_next_steps
}

main "$@"
EOF

sudo bash ./setup-dev13-devstation.sh
