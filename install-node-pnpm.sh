#!/usr/bin/env bash
# install-node-pnpm.sh — Instalador Node.js + pnpm (para Debian)
set -euo pipefail

NODEVER=24.10.0   # puedes cambiar por otra versión LTS
PNPMVER=10.0.0

echo "==> Instalando Node.js ${NODEVER} desde mirror de Tsinghua..."

mkdir -p /usr/local/node && cd /usr/local/node
curl -LO https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/v${NODEVER}/node-v${NODEVER}-linux-x64.tar.xz
tar -xJf node-v${NODEVER}-linux-x64.tar.xz
ln -sfn node-v${NODEVER}-linux-x64 current
echo 'export PATH=/usr/local/node/current/bin:$PATH' > /etc/profile.d/node.sh
source /etc/profile.d/node.sh

echo "==> Verificando instalación..."
node -v || { echo "Error instalando Node"; exit 1; }

echo "==> Activando Corepack y preparando pnpm..."
corepack enable
corepack prepare pnpm@${PNPMVER} --activate

echo "==> Configurando mirrors (China-friendly)..."
npm config set registry https://registry.npmmirror.com
pnpm config set registry https://registry.npmmirror.com

echo "==> Verificación final:"
node -v
pnpm -v
echo "Node y pnpm instalados correctamente."
