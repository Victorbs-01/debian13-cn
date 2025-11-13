#!/usr/bin/env bash
# install-node-pnpm.sh — Debian: Node 24 + pnpm 10 (idempotente, China-friendly)
set -euo pipefail

NODEVER="${NODEVER:-24.10.0}"
PNPMVER="${PNPMVER:-10.3.0}"
NODE_DIR="/usr/local/node"
NODE_BIN="$NODE_DIR/current/bin"
NODE_EXE="$NODE_BIN/node"

log(){ echo -e "\033[1;32m==>\033[0m $*"; }
warn(){ echo -e "\033[1;33m!!\033[0m $*"; }

# Detecta el usuario real que llamó sudo
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

# --- 1) Instalar Node si falta ---
if [ -x "$NODE_EXE" ]; then
  log "Node ya está en $NODE_EXE (versión: $("$NODE_EXE" -v))"
else
  log "Instalando Node v$NODEVER en $NODE_DIR ..."
  mkdir -p "$NODE_DIR" && cd "$NODE_DIR"
  # Descarga con fallback (TUNA → npmmirror)
  curl -fL --retry 5 -o node.tar.xz "https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/v${NODEVER}/node-v${NODEVER}-linux-x64.tar.xz" \
  || curl -fL --retry 5 -o node.tar.xz "https://registry.npmmirror.com/-/binary/node/v${NODEVER}/node-v${NODEVER}-linux-x64.tar.xz"
  # Verificar que realmente sea .xz
  xz -t node.tar.xz
  tar -xJf node.tar.xz
  ln -sfn "node-v${NODEVER}-linux-x64" current
  rm -f node.tar.xz
fi

# --- 2) Asegurar PATH global y de usuario ---
log "Asegurando PATH global y del usuario..."
echo 'export PATH=/usr/local/node/current/bin:$PATH' > /etc/profile.d/node.sh
chmod 644 /etc/profile.d/node.sh

# Añade a perfiles de usuario (por si XFCE no carga /etc/profile.d)
for f in "$REAL_HOME/.bashrc" "$REAL_HOME/.profile"; do
  touch "$f"
  grep -q '/usr/local/node/current/bin' "$f" || echo 'export PATH=/usr/local/node/current/bin:$PATH' >> "$f"
done
chown "$REAL_USER":"$REAL_USER" "$REAL_HOME/.bashrc" "$REAL_HOME/.profile"

# Exporta PATH para esta misma ejecución (efecto inmediato)
export PATH="/usr/local/node/current/bin:$PATH"

# --- 3) Corepack + pnpm ---
log "Activando Corepack y pnpm@$PNPMVER..."
corepack enable
corepack prepare "pnpm@${PNPMVER}" --activate

# --- 4) Mirrors npm/pnpm (China-friendly) ---
log "Configurando mirrors npm/pnpm..."
npm config set registry https://registry.npmmirror.com >/dev/null
pnpm config set registry https://registry.npmmirror.com >/dev/null

# --- 5) Mostrar versiones y consejo ---
log "Verificación:"
echo "node: $(node -v)"
echo "npm : $(npm -v)"
echo "pnpm: $(pnpm -v)"

log "PATH aplicado. Si algún terminal no lo ve aún, ejecuta:"
echo "  source /etc/profile.d/node.sh"
