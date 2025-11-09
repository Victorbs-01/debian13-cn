cat > switch-to-tsinghua-trixie.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
if [[ "${CODENAME}" != "trixie" ]]; then
  echo "Este equipo no reporta 'trixie' (es: ${CODENAME}). Aborta por seguridad."
  echo "Si estás seguro, vuelve a ejecutar con: FORCE=1 bash $0"
  [[ "${FORCE:-0}" == "1" ]] || exit 1
fi

echo "Respaldando /etc/apt/sources.list..."
cp -a /etc/apt/sources.list "/etc/apt/sources.list.bak.$(date -Iseconds)" || true

echo "Escribiendo mirrors de Tsinghua (HTTPS) para trixie..."
cat >/etc/apt/sources.list <<LIST
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-backports main contrib non-free non-free-firmware

# (Opcional) Código fuente:
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-backports main contrib non-free non-free-firmware
LIST

echo "Actualizando índices..."
apt-get update -y

echo "Verificando certificados y curl..."
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl

echo "Listo."
echo "Backup: /etc/apt/sources.list.bak.*"
EOF

sudo bash switch-to-tsinghua-trixie.sh
