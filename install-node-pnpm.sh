#!/usr/bin/env bash
# install-node-pnpm.sh — Debian: Node + pnpm (idempotente, China-friendly)
set -euo pipefail

NODEVER="${NODEVER:-24.10.0}"
PNPMVER="${PNPMVER:-10.0.0}"
NODE_DIR="/usr/local/node"
NODE_BIN="$NODE_DIR/current/bin"
NODE_EXE="$NODE_BIN/node"

log(){ echo -e "\033[1;32m==>\033[0m $*"; }
warn(){ echo -e "\033[1;33m!!\033[0m $*"; }

# 0) PATH para esta sesión (por si ya estaba instalado)
export PATH="$NODE_BIN:$PATH"

# 1) ¿Node ya está instalado ahí?
if command -v node >/dev/null 2>&1 && [[ "$(command -v node)" == "$NODE_EXE" ]]; then
  log "Node ya está instalado en $NODE_EXE (versión: $(node -v))"
else
  log "Instalando Node v$NODEVER en $NODE_DIR ..."
  mkdir -p "$NODE_DIR" && cd "$NODE_DIR"
  # Descarga con fallback (TUNA → npmmirror)
  curl -fL --retry 5 -o node.tar.xz "https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/v${NODEVER}/node-v${NODEVER}-linux-x64.tar.xz" \
  || curl -fL --retry 5 -o node.tar.xz "https://registry.npmmirror.com/-/binary/node/v${NODEVER}/node-v${NODEVER}-linux-x64.tar.xz"

  # Verifica que sea un .xz válido
  xz -t node.tar.xz || { echo "Archivo descargado no es .xz válido"; exit 1; }

  tar -xJf node.tar.xz
  ln -sfn "node-v${NODEVER}-linux-x64" current
  rm -f node.tar.xz
  export PATH="$NODE_BIN:$PATH"
fi

# 2) Persistir PATH (global + usuario)
log "Asegurando PATH global y de usuario..."
echo 'export PATH=/usr/local/node/current/bin:$PATH' >/etc/profile.d/node.sh
chmod 644 /etc/profile.d/node.sh

USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
for f in "$USER_HOME/.bashrc" "$USER_HOME/.profile"; do
  grep -q '/usr/local/node/current/bin' "$f" 2>/dev/null || echo 'export PATH=/usr/local/node/current/bin:$PATH' >> "$f"
done

# 3) Corepack + pnpm
log "Activando Corepack y pnpm@$PNPMVER..."
corepack enable
corepack prepare "pnpm@${PNPMVER}" --activate

# 4) Mirrors npm/pnpm (rápido en China)
log "Configurando mirrors npm/pnpm..."
npm config set registry https://registry.npmmirror.com >/dev/null
pnpm config set registry https://registry.npmmirror.com >/dev/null

# 5) Mostrar versiones
log "Verificación:"
echo "node: $(node -v)"
echo "npm : $(npm -v)"
echo "pnpm: $(pnpm -v)"

log "Listo. Abre una terminal nueva o ejecuta:  source /etc/profile.d/node.sh"
