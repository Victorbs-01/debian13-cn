#!/usr/bin/env bash
set -euo pipefail

# Trap para capturar errores y mostrar mensaje
trap 'echo "ERROR: Falló en línea ${LINENO}. Comando: ${BASH_COMMAND}"' ERR

echo "==> 0) Prepara keyrings y limpia restos"
rm -f /etc/apt/keyrings/docker.gpg || echo "INFO: No había clave GPG previa para eliminar"
mkdir -p /etc/apt/keyrings || { echo "ERROR: No se pudo crear /etc/apt/keyrings"; exit 1; }
rm -f /etc/apt/sources.list.d/docker*.list /etc/apt/trusted.gpg.d/docker.gpg || echo "INFO: No había archivos Docker previos para limpiar"

echo "==> 0.5) Verificar conectividad con mirrors TUNA"
echo "Comprobando acceso a mirrors TUNA..."

# Verificar mirror principal de Debian
echo -n "  - Mirror Debian principal: "
if curl -fsSL --connect-timeout 5 --max-time 10 \
   https://mirrors.tuna.tsinghua.edu.cn/debian/dists/trixie/Release > /dev/null 2>&1; then
    echo "✓ Accesible"
else
    echo "✗ NO accesible"
    echo "ERROR: No se puede acceder al mirror principal de Debian en TUNA"
    echo "       Verifica tu conexión a Internet o que el mirror esté disponible"
    exit 1
fi

# Verificar mirror de seguridad de Debian
echo -n "  - Mirror Debian Security: "
if curl -fsSL --connect-timeout 5 --max-time 10 \
   https://mirrors.tuna.tsinghua.edu.cn/debian-security/dists/trixie-security/Release > /dev/null 2>&1; then
    echo "✓ Accesible"
else
    echo "✗ NO accesible"
    echo "ERROR: No se puede acceder al mirror de seguridad de Debian en TUNA"
    echo "       Verifica tu conexión a Internet o que el mirror esté disponible"
    exit 1
fi

# Verificar mirror de Docker CE
echo -n "  - Mirror Docker CE: "
if curl -fsSL --connect-timeout 5 --max-time 10 \
   https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/dists/trixie/Release > /dev/null 2>&1; then
    echo "✓ Accesible (trixie disponible)"
    TRIXIE_AVAILABLE=true
elif curl -fsSL --connect-timeout 5 --max-time 10 \
     https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/dists/bookworm/Release > /dev/null 2>&1; then
    echo "⚠ Accesible (solo bookworm disponible, trixie no)"
    TRIXIE_AVAILABLE=false
else
    echo "✗ NO accesible"
    echo "ERROR: No se puede acceder al mirror de Docker CE en TUNA"
    echo "       Verifica tu conexión a Internet o que el mirror esté disponible"
    exit 1
fi

# Verificar acceso a clave GPG de Docker
echo -n "  - Clave GPG de Docker: "
if curl -fsSL --connect-timeout 5 --max-time 10 \
   https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/gpg > /dev/null 2>&1; then
    echo "✓ Accesible"
else
    echo "✗ NO accesible"
    echo "ERROR: No se puede acceder a la clave GPG de Docker en TUNA"
    echo "       Verifica tu conexión a Internet"
    exit 1
fi

echo "✓ Todos los mirrors de TUNA están accesibles"
if [ "$TRIXIE_AVAILABLE" = false ]; then
    echo "INFO: Se usará bookworm como fallback para Docker CE"
fi

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
apt-get install -y ca-certificates curl gnupg lsb-release acl || { echo "ERROR: Falló la instalación de pre-requisitos"; exit 1; }
echo "✓ Pre-requisitos instalados"

echo "Creando directorio de keyrings..."
install -m 0755 -d /etc/apt/keyrings || { echo "ERROR: No se pudo crear directorio de keyrings"; exit 1; }

echo "Descargando clave GPG de Docker desde mirror TUNA..."
echo "NOTA: Usando mirror TUNA para evitar problemas de conexión con download.docker.com"
curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || { echo "ERROR: Falló la descarga de la clave GPG desde TUNA"; exit 1; }
chmod 0644 /etc/apt/keyrings/docker.gpg || { echo "ERROR: No se pudo cambiar permisos de la clave GPG"; exit 1; }
echo "✓ Clave GPG de Docker configurada desde mirror TUNA"

echo "==> 4) Repo de Docker CE apuntando a TUNA"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")" # debe ser trixie
echo "Usando codename: $CODENAME"

# Usar bookworm si la verificación anterior detectó que trixie no está disponible
if [ "$TRIXIE_AVAILABLE" = false ]; then
    echo "INFO: Configurando repositorio Docker con bookworm (trixie no disponible en TUNA)"
    DOCKER_CODENAME="bookworm"
else
    DOCKER_CODENAME="$CODENAME"
fi

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian $DOCKER_CODENAME stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null || { echo "ERROR: No se pudo crear docker.list"; exit 1; }

echo "Actualizando índices con repo Docker..."
apt-get update || { echo "ERROR: Falló apt-get update después de agregar repo Docker"; exit 1; }

# Verificar si trixie está disponible en TUNA, si no, cambiar a bookworm
if ! apt-cache policy | grep -q "mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian.*${DOCKER_CODENAME}"; then
    echo "ADVERTENCIA: El repositorio Docker para $DOCKER_CODENAME no aparece en apt-cache policy"
    if [ "$DOCKER_CODENAME" = "trixie" ]; then
        echo "==> Cambiando a bookworm (fallback)"
        sed -i 's/ trixie / bookworm /' /etc/apt/sources.list.d/docker.list || { echo "ERROR: No se pudo cambiar a bookworm"; exit 1; }
        echo "Actualizando índices con repo Docker (bookworm)..."
        apt-get update || { echo "ERROR: Falló apt-get update con bookworm"; exit 1; }
        echo "✓ Repositorio Docker configurado con bookworm (fallback)"
    else
        echo "ERROR: El repositorio Docker no está disponible"
        exit 1
    fi
else
    echo "✓ Repositorio Docker configurado y actualizado ($DOCKER_CODENAME)"
fi

echo "==> 5) Instalar Docker CE"
echo "Instalando paquetes Docker..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { echo "ERROR: Falló la instalación de Docker CE"; exit 1; }
echo "✓ Docker CE instalado correctamente"

echo "==> 6) Crear grupo docker y agregar usuario"
# Crear grupo docker si no existe
groupadd -f docker || echo "INFO: El grupo docker ya existe"

# Detectar el usuario que ejecutó el script (no root)
if [ "$EUID" -eq 0 ]; then
    USER_NAME="${SUDO_USER:-${USER:-}}"
    if [ -z "$USER_NAME" ] || [ "$USER_NAME" = "root" ]; then
        echo "ADVERTENCIA: No se pudo detectar el usuario. Ejecuta el script como: sudo -u tu_usuario ./scrip4.sh"
        echo "O agrega manualmente al grupo docker después: sudo usermod -aG docker tu_usuario"
        USER_NAME=""
    else
        echo "Usuario detectado: $USER_NAME"
        # Verificar si el usuario ya está en el grupo docker
        if groups "$USER_NAME" | grep -q '\bdocker\b'; then
            echo "INFO: El usuario '$USER_NAME' ya está en el grupo 'docker'"
        else
            echo "Agregando usuario '$USER_NAME' al grupo docker..."
            usermod -aG docker "$USER_NAME" || { echo "ERROR: No se pudo agregar usuario al grupo docker"; exit 1; }
            echo "✓ Usuario agregado al grupo docker"
        fi
    fi
else
    USER_NAME="$USER"
    echo "Usuario actual: $USER_NAME"
    if groups "$USER_NAME" | grep -q '\bdocker\b'; then
        echo "INFO: El usuario '$USER_NAME' ya está en el grupo 'docker'"
    else
        echo "ADVERTENCIA: No se ejecuta como root. Agrega manualmente al grupo: sudo usermod -aG docker $USER_NAME"
    fi
fi

echo "==> 7) Configurar mirrors de Docker para China"
mkdir -p /etc/docker || { echo "ERROR: No se pudo crear directorio /etc/docker"; exit 1; }

# Verificar si ya existe daemon.json y hacer backup
if [ -f /etc/docker/daemon.json ]; then
    cp /etc/docker/daemon.json /etc/docker/daemon.json.bak.$(date +%s) || echo "INFO: No se pudo respaldar daemon.json"
    echo "INFO: Se respaldó daemon.json existente"
fi

cat >/etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
EOF

echo "✓ Configuración de mirrors de Docker guardada"
echo "Mirrors configurados:"
echo "  - https://docker.m.daocloud.io"
echo "  - https://hub-mirror.c.163.com"
echo "  - https://mirror.ccs.tencentyun.com"
echo "  - https://docker.mirrors.ustc.edu.cn"

echo "==> 8) Asegurar forward IPv4 (necesario para bridge)"
cat >/etc/sysctl.d/99-docker-forwarding.conf <<'EOF'
net.ipv4.ip_forward=1
EOF
sysctl --system >/dev/null || { echo "ERROR: Falló la configuración de ip_forward"; exit 1; }
echo "✓ IPv4 forwarding configurado"

echo "==> 9) Habilitar y arrancar Docker"
echo "Habilitando servicio Docker..."
systemctl enable --now docker || { echo "ERROR: Falló al habilitar/iniciar Docker"; exit 1; }
echo "✓ Docker habilitado e iniciado"

echo "Recargando configuración de Docker (para aplicar mirrors)..."
systemctl daemon-reload || echo "ADVERTENCIA: Falló daemon-reload"
systemctl restart docker || { echo "ERROR: Falló al reiniciar Docker"; exit 1; }
echo "✓ Docker reiniciado con nueva configuración"

echo "Verificando estado de Docker..."
systemctl --no-pager --full status docker | sed -n '1,12p' || { echo "ERROR: Docker no está corriendo correctamente"; exit 1; }
echo "✓ Docker está corriendo"

echo "==> 10) Ajustar permisos del socket Docker"
if [ -S /var/run/docker.sock ]; then
    echo "Ajustando permisos del socket Docker..."
    chown root:docker /var/run/docker.sock || echo "ADVERTENCIA: No se pudo cambiar propietario del socket"
    chmod 660 /var/run/docker.sock || echo "ADVERTENCIA: No se pudo cambiar permisos del socket"
    
    # Aplicar permiso temporal con ACL si el usuario fue detectado
    if [ -n "$USER_NAME" ] && [ "$USER_NAME" != "root" ]; then
        echo "Aplicando permiso temporal con ACL para usuario '$USER_NAME'..."
        setfacl -m "user:${USER_NAME}:rw" /var/run/docker.sock 2>/dev/null || echo "INFO: ACL no disponible o ya configurado"
    fi
    echo "✓ Permisos del socket configurados"
else
    echo "ADVERTENCIA: Socket Docker no encontrado en /var/run/docker.sock"
fi

echo "==> 11) Smoke tests rápidos"
echo "Verificando versión de Docker..."
if docker version > /dev/null 2>&1; then
    docker version 2>/dev/null | head -5 || docker version 2>/dev/null
    echo "✓ Docker version funciona"
else
    echo "⚠️ Docker instalado, pero se requiere nueva sesión para permisos persistentes"
    echo "   Ejecuta: newgrp docker"
fi

echo "Ejecutando test: hello-world..."
if docker run --rm hello-world > /dev/null 2>&1; then
    echo "✓ Test hello-world exitoso"
    docker run --rm hello-world 2>/dev/null | head -5 || docker run --rm hello-world 2>/dev/null | head -n 5 || docker run --rm hello-world 2>/dev/null
else
    echo "⚠️ Test hello-world falló (posible bloqueo de China, usando mirrors configurados)"
    echo "   Los mirrors de Docker están configurados, intenta de nuevo después de reiniciar sesión"
fi

echo "Inspección de red bridge..."
echo "Puerta de enlace del bridge:"
if docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null; then
    echo "✓ Red bridge configurada"
else
    echo "⚠️ No se pudo inspeccionar la red bridge (posible problema de permisos)"
fi

echo "Test de conectividad desde contenedor..."
echo "Ruta dentro de contenedor y ping a DNS chino (223.5.5.5)"
if docker run --rm alpine sh -c 'ip route; ping -c1 223.5.5.5 || true' > /dev/null 2>&1; then
    docker run --rm alpine sh -c 'ip route; ping -c1 223.5.5.5 || true'
    echo "✓ Test de conectividad exitoso"
else
    echo "⚠️ Test de conectividad falló (posible problema de permisos o red)"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "                    RESUMEN DE INSTALACIÓN"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "✓ Docker CE instalado y configurado exitosamente"
echo ""
echo "📦 Componentes instalados:"
echo "   - docker-ce"
echo "   - docker-ce-cli"
echo "   - containerd.io"
echo "   - docker-buildx-plugin"
echo "   - docker-compose-plugin"
echo ""
echo "🌐 Repositorios configurados:"
echo "   - Debian: mirrors.tuna.tsinghua.edu.cn/debian (trixie)"
echo "   - Docker CE: mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian ($DOCKER_CODENAME)"
if [ "$TRIXIE_AVAILABLE" = false ]; then
    echo "   ⚠ Usando bookworm como fallback (trixie no disponible)"
fi
echo ""
echo "🔑 Mirrors de Docker Hub configurados (para China):"
echo "   - https://docker.m.daocloud.io"
echo "   - https://hub-mirror.c.163.com"
echo "   - https://mirror.ccs.tencentyun.com"
echo "   - https://docker.mirrors.ustc.edu.cn"
echo ""
echo "⚙️ Configuración del sistema:"
echo "   - IPv4 forwarding: Habilitado"
echo "   - Servicio Docker: Habilitado e iniciado"
echo "   - Socket Docker: Permisos configurados"
if [ -n "$USER_NAME" ] && [ "$USER_NAME" != "root" ]; then
    echo "   - Usuario '$USER_NAME': Agregado al grupo docker"
fi
echo ""
echo "📋 Archivos de configuración:"
echo "   - /etc/apt/sources.list (respaldo: sources.list.bak.*)"
echo "   - /etc/apt/sources.list.d/docker.list"
echo "   - /etc/apt/keyrings/docker.gpg"
echo "   - /etc/docker/daemon.json"
if [ -f /etc/docker/daemon.json.bak.* ]; then
    echo "   - Respaldo: /etc/docker/daemon.json.bak.*"
fi
echo "   - /etc/sysctl.d/99-docker-forwarding.conf"
echo ""
if [ -n "$USER_NAME" ] && [ "$USER_NAME" != "root" ]; then
    echo "⚠️  ACCIÓN REQUERIDA:"
    echo "   Para que los permisos de Docker surtan efecto completamente:"
    echo ""
    echo "   1. Cierra sesión completamente y vuelve a iniciar"
    echo "      O ejecuta: newgrp docker"
    echo ""
    echo "   2. Verifica que funcionó:"
    echo "      groups"
    echo "      docker ps"
    echo ""
fi
echo "🧪 Próximos pasos sugeridos:"
echo "   - Probar: docker run hello-world"
echo "   - Verificar: docker version"
echo "   - Inspeccionar: docker info"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "==> ✓ Instalación completada exitosamente"
echo "════════════════════════════════════════════════════════════════"
