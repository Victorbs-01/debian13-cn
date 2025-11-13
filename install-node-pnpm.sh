#!/usr/bin/env bash
set -euo pipefail

# Versiones
NODEVER=${NODEVER:-24.10.0}
PNPMVER=${PNPMVER:-10.3.0}

echo "==> Instalando Node.js ${NODEVER}..."
mkdir -p /usr/local/node && cd /usr/local/node

# Descarga desde mirrors rápidos (Tsinghua o npmmirror)
curl -fL --retry 5 -o node.tar.xz \
  https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/v${NODEVER}/node-v${NODEVER}-linux-x64.tar.xz || \
curl -fL --retry 5 -o node.tar.xz \
  https://registry.npmmirror.com/-/binary/node/v${NODEVER}/node-v${NODEVER}-linux-x64.tar.xz

# Verificación básica
if ! file node.tar.xz | grep -q 'XZ compressed data'; then
  echo "❌ Descarga inválida (no es un .tar.xz válido)"
  exit 1
fi

tar -xJf node.tar.xz
ln -sfn node-v${NODEVER}-linux-x64 current
printf 'export PATH=/usr/local/node/current/bin:$PATH\n' > /etc/profile.d/node.sh
source /etc/profile.d/node.sh

echo "==> Verificando Node..."
node -v

echo "==> Activando Corepack y preparando pnpm ${PNPMVER}..."
corepack enable
corepack prepare pnpm@${PNPMVER} --activate

echo "==> Configurando mirrors (npmmirror para China)..."
npm config set registry https://registry.npmmirror.com
pnpm config set registry https://registry.npmmirror.com

echo "==> Verificación final:"
node -v
pnpm -v
echo "✅ Node y pnpm ${PNPMVER} instalados correctamente."

