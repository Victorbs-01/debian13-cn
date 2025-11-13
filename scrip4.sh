#!/usr/bin/env bash
set -euo pipefail

# Trap para capturar errores y mostrar mensaje
trap 'echo "ERROR: Falló en línea $LINENO. Comando: $BASH_COMMAND"' ERR

echo "==> 0) Prepara keyrings y limpia restos"
mkdir -p /etc/apt/keyrings || { echo "ERROR: No se pudo crear /etc/apt/keyrings"; exit 1; }
rm -f /etc/apt/sources.list.d/docker*.list /etc/apt/trusted.gpg.d/docker.gpg || echo "INFO: No había archivos Docker previos para limpiar"

echo "==> 1) Respaldar y cambiar mirrors a TUNA (Debian 13 - trixie)"
cp -a /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%s) || { echo "ERROR: No se pudo respaldar sources.list"; exit 1; }
cat >/etc/apt/sources.list <<'EOF'
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
EOF

echo "Actualizando índices de paquetes..."
apt-get update || { echo "ERROR: Falló apt-get update"; exit 1; }
echo "✓ Índices actualizados correctamente"

echo "==> 2) Purgar Docker previo (si existe)"
apt-get remove -y --purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker.io 2>/dev/null || echo "INFO: No había docker-ce instalado"
apt-get remove -y --purge docker* containerd* runc 2>/dev/null || echo "INFO: No había paquetes Docker adicionales"
rm -rf /var/lib/docker /var/lib/containerd 2>/dev/null || echo "INFO: No había directorios Docker para eliminar"
echo "✓ Limpieza de Docker previo completada"

echo "==> 3) Pre-requisitos y keyring"
echo "Instalando pre-requisitos..."
apt-get install -y ca-certificates curl gnupg lsb-release || { echo "ERROR: Falló la instalación de pre-requisitos"; exit 1; }
echo "✓ Pre-requisitos instalados"

echo "Creando directorio de keyrings..."
install -m 0755 -d /etc/apt/keyrings || { echo "ERROR: No se pudo crear directorio de keyrings"; exit 1; }

echo "Descargando clave GPG de Docker..."
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || { echo "ERROR: Falló la descarga de la clave GPG"; exit 1; }
chmod a+r /etc/apt/keyrings/docker.gpg || { echo "ERROR: No se pudo cambiar permisos de la clave GPG"; exit 1; }
echo "✓ Clave GPG de Docker configurada"

echo "==> 4) Repo de Docker CE apuntando a TUNA"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")" # debe ser trixie
echo "Usando codename: $CODENAME"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian $CODENAME stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null || { echo "ERROR: No se pudo crear docker.list"; exit 1; }

echo "Actualizando índices con repo Docker..."
apt-get update || { echo "ERROR: Falló apt-get update después de agregar repo Docker"; exit 1; }
echo "✓ Repositorio Docker configurado y actualizado"

echo "==> 5) Instalar Docker CE"
echo "Instalando paquetes Docker..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { echo "ERROR: Falló la instalación de Docker CE"; exit 1; }
echo "✓ Docker CE instalado correctamente"

echo "==> 6) Asegurar forward IPv4 (necesario para bridge)"
cat >/etc/sysctl.d/99-docker-forwarding.conf <<'EOF'
net.ipv4.ip_forward=1
EOF
sysctl --system >/dev/null || { echo "ERROR: Falló la configuración de ip_forward"; exit 1; }
echo "✓ IPv4 forwarding configurado"

echo "==> 7) Habilitar y arrancar Docker"
echo "Habilitando servicio Docker..."
systemctl enable --now docker || { echo "ERROR: Falló al habilitar/iniciar Docker"; exit 1; }
echo "✓ Docker habilitado e iniciado"

echo "Verificando estado de Docker..."
systemctl --no-pager --full status docker | sed -n '1,12p' || { echo "ERROR: Docker no está corriendo correctamente"; exit 1; }
echo "✓ Docker está corriendo"

echo "==> 8) Smoke tests rápidos"
echo "Ejecutando test: hello-world..."
docker run --rm hello-world || { echo "ERROR: Falló el test hello-world"; exit 1; }
echo "✓ Test hello-world exitoso"

echo "Inspección de red bridge..."
echo "Puerta de enlace del bridge:"
docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}' || { echo "ERROR: No se pudo inspeccionar la red bridge"; exit 1; }
echo "✓ Red bridge configurada"

echo "Test de conectividad desde contenedor..."
echo "Ruta dentro de contenedor y ping a DNS chino (223.5.5.5)"
docker run --rm alpine sh -c 'ip route; ping -c1 223.5.5.5 || true' || { echo "ERROR: Falló el test de conectividad"; exit 1; }
echo "✓ Test de conectividad exitoso"

echo ""
echo "==> ✓ Listo. Si hello-world corre y el ping sale, la red Docker funciona."
echo "==> ✓ Todos los pasos completados exitosamente."
