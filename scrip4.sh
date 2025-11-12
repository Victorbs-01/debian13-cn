#!/usr/bin/env bash
set -euo pipefail

echo "==> 1) Respaldar y cambiar mirrors a TUNA (Debian 13 - trixie)"
cp -a /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%s)
cat >/etc/apt/sources.list <<'EOF'
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
EOF

apt-get update

echo "==> 2) Purgar Docker previo (si existe)"
apt-get remove -y --purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker.io || true
apt-get remove -y --purge docker* containerd* runc || true
rm -rf /var/lib/docker /var/lib/containerd || true

echo "==> 3) Pre-requisitos y keyring"
apt-get install -y ca-certificates curl gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "==> 4) Repo de Docker CE apuntando a TUNA"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")" # debe ser trixie
echo "Usando codename: $CODENAME"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian $CODENAME stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

echo "==> 5) Instalar Docker CE"
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> 6) Asegurar forward IPv4 (necesario para bridge)"
cat >/etc/sysctl.d/99-docker-forwarding.conf <<'EOF'
net.ipv4.ip_forward=1
EOF
sysctl --system >/dev/null

echo "==> 7) Habilitar y arrancar Docker"
systemctl enable --now docker
systemctl --no-pager --full status docker | sed -n '1,12p'

echo "==> 8) Smoke tests rápidos"
# Hello World
docker run --rm hello-world

# Inspección de red bridge y prueba de conectividad saliente desde un contenedor.
echo "Puerta de enlace del bridge:"
docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}'

echo "Ruta dentro de contenedor y ping a DNS chino (223.5.5.5)"
docker run --rm alpine sh -c 'ip route; ping -c1 223.5.5.5 || true'

echo "==> Listo. Si hello-world corre y el ping sale, la red Docker funciona."
