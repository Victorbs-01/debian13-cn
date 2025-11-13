# Script de Instalación de Docker CE en Debian 13 (Trixie)

## Descripción

Este script automatiza la instalación limpia de Docker CE en Debian 13 (Trixie), configurando los repositorios para usar el mirror TUNA de Tsinghua University (China) para mejorar la velocidad de descarga en regiones específicas. El script también realiza pruebas de funcionamiento (smoke tests) para verificar que Docker está correctamente instalado y configurado.

**Nota importante**: Este script está optimizado para funcionar en China, usando el mirror TUNA tanto para los repositorios como para la clave GPG de Docker, evitando así problemas de conexión con el sitio oficial de Docker.

## Requisitos Previos

### Configurar Usuario con Permisos Sudo

**Este script requiere permisos sudo para ejecutarse.** Si el usuario no tiene permisos sudo, un administrador debe agregarlo primero.

#### Opción 1: Como root directo (Más simple)

```bash
# Cambiar a root
su -

# Agregar usuario al grupo sudo
usermod -aG sudo tu_usuario
```

#### Opción 2: Si ya tienes acceso sudo

```bash
# Agregar usuario al grupo sudo directamente
sudo usermod -aG sudo tu_usuario
```

#### Opción 3: Usar script5.sh (Recomendado)

```bash
# Ejecutar el script de configuración de usuario
sudo ./script5.sh tu_usuario
```

**Importante**: Después de agregar al usuario al grupo sudo:
- El usuario debe **cerrar sesión completamente** y volver a iniciar
- O ejecutar `newgrp sudo` en su sesión actual

Para verificar que funcionó:
```bash
groups
sudo -l
```

## Uso del script

```bash
# Dar permisos de ejecución
chmod +x scrip4.sh

# Ejecutar como root
sudo ./scrip4.sh

# O ejecutar directamente con bash como root
sudo bash scrip4.sh
```


## Características

- **Verificación previa de mirrors**: Comprueba la conectividad con todos los mirrors TUNA antes de configurarlos
- **Limpieza previa**: Elimina cualquier instalación previa de Docker para evitar conflictos
- **Configuración de mirrors**: Cambia los repositorios de Debian y Docker al mirror TUNA
- **Clave GPG desde TUNA**: Descarga la clave GPG desde el mirror TUNA para evitar problemas de conexión con download.docker.com
- **Detección temprana**: Detecta si trixie está disponible en TUNA antes de configurar los repositorios
- **Fallback automático**: Si trixie no está disponible en TUNA, cambia automáticamente a bookworm
- **Configuración de usuario**: Agrega automáticamente al usuario al grupo docker
- **Mirrors de Docker Hub**: Configura mirrors chinos para acelerar la descarga de imágenes
- **Permisos del socket**: Ajusta permisos del socket Docker y aplica ACL temporal
- **Instalación completa**: Instala Docker CE con todos los componentes necesarios
- **Configuración de red**: Habilita el forwarding IPv4 necesario para las redes bridge de Docker
- **Pruebas automáticas**: Ejecuta tests básicos para verificar la instalación
- **Resumen final**: Muestra un resumen completo de la instalación al finalizar

## Requisitos

- Sistema operativo: Debian 13 (Trixie) o compatible
- Permisos: Ejecutar como root o con sudo (ver sección "Requisitos Previos" arriba)
- Conexión a Internet: Requerida para descargar paquetes y claves GPG
- Acceso a mirrors TUNA: El script verifica la conectividad antes de continuar

## Pasos del Script

### Paso 0: Preparación y Limpieza
- Elimina cualquier clave GPG corrupta previa de Docker
- Crea el directorio `/etc/apt/keyrings` si no existe
- Elimina archivos de configuración previos de Docker (repositorios y claves GPG antiguas)

### Paso 0.5: Verificación de Conectividad con Mirrors TUNA
**NUEVO**: Antes de configurar los repositorios, el script verifica la conectividad con todos los mirrors necesarios:
- **Mirror Debian principal**: Verifica acceso a `mirrors.tuna.tsinghua.edu.cn/debian/dists/trixie/Release`
- **Mirror Debian Security**: Verifica acceso a `mirrors.tuna.tsinghua.edu.cn/debian-security/dists/trixie-security/Release`
- **Mirror Docker CE**: Verifica acceso a los repositorios Docker (trixie y bookworm como fallback)
- **Clave GPG de Docker**: Verifica acceso a la clave GPG en TUNA

Si algún mirror no está accesible, el script se detiene con un mensaje de error claro, evitando configuraciones que no funcionarán.

**Ventajas**:
- Detecta problemas de conectividad antes de modificar la configuración del sistema
- Evita configurar repositorios que no están disponibles
- Informa claramente qué mirror está disponible (trixie o bookworm)
- Usa timeouts cortos (5 segundos de conexión, 10 segundos máximo) para evitar bloqueos largos

### Paso 1: Configuración de Repositorios Debian
- Realiza un respaldo de `/etc/apt/sources.list` con timestamp
- Configura los repositorios de Debian para usar el mirror TUNA:
  - Repositorio principal (trixie)
  - Actualizaciones (trixie-updates)
  - Seguridad (trixie-security)
- Actualiza los índices de paquetes

### Paso 2: Limpieza de Docker Previo
- Desinstala cualquier versión previa de Docker (docker-ce, docker.io, containerd, etc.)
- Elimina directorios de datos de Docker (`/var/lib/docker`, `/var/lib/containerd`)
- Este paso es seguro si Docker no está instalado (muestra mensajes informativos)

### Paso 3: Pre-requisitos y Clave GPG
- Instala herramientas necesarias: `ca-certificates`, `curl`, `gnupg`, `lsb-release`, `acl`
- **Descarga la clave GPG de Docker desde el mirror TUNA** (no desde download.docker.com)
- Configura la clave en `/etc/apt/keyrings/docker.gpg` con permisos 0644
- Esto evita problemas de conexión/reset que pueden ocurrir al descargar desde el sitio oficial

### Paso 4: Repositorio Docker CE
- Detecta automáticamente el codename del sistema (debe ser "trixie")
- Usa la información de la verificación previa para determinar si usar trixie o bookworm
- Configura el repositorio de Docker CE apuntando al mirror TUNA
- Actualiza los índices de paquetes con el nuevo repositorio
- **Verifica si trixie está disponible**: Si el repositorio Docker para trixie no está sincronizado aún en TUNA, cambia automáticamente a bookworm como fallback

### Paso 5: Instalación de Docker CE
- Instala los siguientes paquetes:
  - `docker-ce`: Motor de Docker
  - `docker-ce-cli`: Interfaz de línea de comandos
  - `containerd.io`: Runtime de contenedores
  - `docker-buildx-plugin`: Plugin para builds avanzados
  - `docker-compose-plugin`: Plugin para Compose

### Paso 6: Crear Grupo Docker y Agregar Usuario
**NUEVO**: Configuración automática de permisos de usuario:
- Crea el grupo `docker` si no existe
- Detecta automáticamente el usuario que ejecutó el script (no root)
- Verifica si el usuario ya está en el grupo docker antes de agregarlo
- Agrega al usuario al grupo docker para permitir ejecutar comandos Docker sin sudo
- Muestra mensajes informativos si no se puede detectar el usuario

**Nota**: El usuario debe cerrar sesión y volver a iniciar para que los cambios de grupo surtan efecto completamente.

### Paso 7: Configurar Mirrors de Docker para China
**NUEVO**: Configuración de mirrors de Docker Hub para acelerar descargas en China:
- Crea el directorio `/etc/docker` si no existe
- Hace backup de `daemon.json` existente si existe
- Configura los siguientes mirrors en `/etc/docker/daemon.json`:
  - `https://docker.m.daocloud.io`
  - `https://hub-mirror.c.163.com`
  - `https://mirror.ccs.tencentyun.com`
  - `https://docker.mirrors.ustc.edu.cn`

Estos mirrors permiten descargar imágenes de Docker Hub más rápido desde China, evitando bloqueos y timeouts.

### Paso 8: Asegurar Forward IPv4 (Necesario para Bridge)
- Habilita el forwarding IPv4 necesario para que las redes bridge de Docker funcionen correctamente
- Configura `net.ipv4.ip_forward=1` en `/etc/sysctl.d/99-docker-forwarding.conf`
- Aplica la configuración con `sysctl --system`

### Paso 9: Habilitar y Arrancar Docker
- Habilita Docker para que se inicie automáticamente al arrancar el sistema
- Inicia el servicio Docker inmediatamente
- Recarga la configuración del sistema (daemon-reload)
- Reinicia Docker para aplicar los mirrors configurados en `daemon.json`
- Verifica que el servicio esté corriendo correctamente

### Paso 10: Ajustar Permisos del Socket Docker
**NUEVO**: Configuración de permisos del socket Docker:
- Ajusta el propietario del socket a `root:docker`
- Configura permisos del socket a `660`
- Aplica permisos temporales con ACL (Access Control List) para el usuario detectado
- Esto permite usar Docker inmediatamente sin reiniciar sesión (hasta que se reinicie el servicio)

**Nota**: Los permisos ACL son temporales. Para permisos persistentes, el usuario debe reiniciar sesión.

### Paso 11: Smoke Tests (Pruebas Rápidas)
El script ejecuta varias pruebas para verificar que todo funciona:

1. **Verificación de versión**: Ejecuta `docker version` para verificar que Docker responde correctamente
2. **Test hello-world**: Ejecuta el contenedor oficial `hello-world` para verificar que Docker puede ejecutar contenedores
3. **Inspección de red bridge**: Verifica que la red bridge predeterminada esté configurada y muestra la puerta de enlace
4. **Test de conectividad**: Ejecuta un contenedor Alpine Linux que:
   - Muestra la tabla de rutas del contenedor
   - Hace ping al DNS público chino (223.5.5.5) para verificar conectividad de red saliente

Todos los tests incluyen manejo de errores y mensajes informativos si fallan.

### Resumen Final
**NUEVO**: Al finalizar, el script muestra un resumen completo que incluye:
- Componentes instalados
- Repositorios configurados
- Mirrors de Docker Hub configurados
- Configuración del sistema
- Archivos de configuración creados/modificados
- Acciones requeridas (si aplica)
- Próximos pasos sugeridos



## Manejo de Errores

El script incluye manejo de errores robusto:
- **Verificación previa**: Comprueba la conectividad con los mirrors antes de modificar la configuración
- **Trap de errores**: Captura cualquier error y muestra la línea y comando que falló
- **Mensajes informativos**: Indica claramente qué paso está ejecutando
- **Mensajes de éxito**: Muestra un checkmark (✓) cuando cada paso se completa exitosamente
- **Mensajes de error**: Muestra mensajes claros si algún paso crítico falla
- **Salida inmediata**: El script se detiene en el primer error crítico (gracias a `set -euo pipefail`)
- **Fallback automático**: Si trixie no está disponible, cambia automáticamente a bookworm
- **Manejo de errores en tests**: Los smoke tests no detienen el script si fallan, solo muestran advertencias

## Solución de Problemas Comunes

### Error: "No se puede acceder al mirror principal de Debian en TUNA"

Este error indica que no hay conectividad con el mirror TUNA. Verifica:

```bash
# Probar conectividad manual
curl -I https://mirrors.tuna.tsinghua.edu.cn/debian/dists/trixie/Release

# Verificar DNS
nslookup mirrors.tuna.tsinghua.edu.cn

# Verificar conectividad general
ping -c 3 mirrors.tuna.tsinghua.edu.cn
```

**Posibles causas**:
- Problemas de red o firewall
- El mirror TUNA está temporalmente no disponible
- Problemas de DNS

### Error: "Connection reset by peer" al descargar clave GPG

Este error ocurre cuando se intenta descargar la clave desde download.docker.com desde China. El script ahora usa el mirror TUNA para evitar este problema.

Si aún experimentas problemas, verifica:
```bash
# Verificar que la clave se descargó correctamente
ls -lh /etc/apt/keyrings/docker.gpg

# Si está vacía o corrupta, elimínala y vuelve a ejecutar el script
sudo rm -f /etc/apt/keyrings/docker.gpg
sudo ./scrip4.sh
```

### Error: "no valid OpenPGP data found"

Esto indica que la clave GPG está corrupta o vacía. El script ahora elimina cualquier clave previa antes de descargar una nueva desde TUNA.

### Repositorio Docker no disponible para trixie

Si TUNA aún no tiene sincronizado el repositorio Docker para trixie, el script automáticamente cambia a bookworm. Esto es normal y funcional, ya que los paquetes Docker son compatibles entre versiones de Debian.

La verificación previa detecta esto antes de configurar los repositorios, mostrando un mensaje informativo como:
```
⚠ Accesible (solo bookworm disponible, trixie no)
INFO: Se usará bookworm como fallback para Docker CE
```

### Los mirrors están accesibles pero el script falla

Si la verificación de mirrors pasa pero el script falla después, puede ser un problema temporal. Intenta:
```bash
# Verificar manualmente los mirrors
curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/debian/dists/trixie/Release | head -5
curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/gpg | head -5

# Si funcionan manualmente, vuelve a ejecutar el script
sudo ./scrip4.sh
```

### Docker funciona pero requiere sudo

Si después de ejecutar el script necesitas usar `sudo` para ejecutar comandos Docker:

1. Verifica que estás en el grupo docker:
   ```bash
   groups
   ```

2. Si no aparece `docker`, cierra sesión completamente y vuelve a iniciar

3. O ejecuta temporalmente:
   ```bash
   newgrp docker
   ```

4. Verifica los permisos del socket:
   ```bash
   ls -l /var/run/docker.sock
   ```

### Las imágenes Docker se descargan lentamente

El script configura mirrors de Docker Hub para acelerar las descargas en China. Si aún son lentas:

1. Verifica que los mirrors están configurados:
   ```bash
   cat /etc/docker/daemon.json
   ```

2. Reinicia Docker para aplicar cambios:
   ```bash
   sudo systemctl restart docker
   ```

3. Verifica que Docker está usando los mirrors:
   ```bash
   docker info | grep -A 10 "Registry Mirrors"
   ```

## Notas Importantes

- El script está diseñado específicamente para **Debian 13 (Trixie)** pero puede usar bookworm como fallback
- Usa el mirror **TUNA** de Tsinghua University para mejorar velocidades de descarga y evitar bloqueos
- **Verifica la conectividad con los mirrors antes de modificar la configuración** del sistema
- **La clave GPG de Docker se descarga desde el mirror TUNA** (no desde download.docker.com) para evitar problemas de conexión en China
- Si trixie no está disponible en TUNA, el script detecta esto temprano y cambia automáticamente a bookworm
- **El usuario se agrega automáticamente al grupo docker** para permitir ejecutar comandos sin sudo
- **Los mirrors de Docker Hub están configurados** para acelerar descargas en China
- **Los permisos del socket se ajustan automáticamente** con ACL temporal para uso inmediato
- Todos los pasos incluyen verificación de errores y mensajes informativos
- Los smoke tests verifican tanto la funcionalidad básica como la conectividad de red
- **El usuario debe tener permisos sudo antes de ejecutar el script** (ver sección "Requisitos Previos")
- **Después de ejecutar el script, el usuario debe cerrar sesión y volver a iniciar** para que los cambios de grupo surtan efecto completamente

## Resultado Esperado

Al finalizar exitosamente, deberías ver:
- Verificación de mirrors completada con todos los checks (✓)
- Docker CE instalado y corriendo
- Usuario agregado al grupo docker
- Mirrors de Docker Hub configurados
- Permisos del socket Docker ajustados
- Servicio habilitado para iniciar automáticamente
- Todos los smoke tests pasando correctamente
- **Resumen final completo** con toda la información de la instalación
- Mensaje final confirmando que todo está listo
- Si se usó bookworm como fallback, verás un mensaje informativo al respecto
- Instrucciones sobre cómo aplicar los cambios de grupo (cerrar sesión o usar `newgrp docker`)

**Ejemplo de salida de verificación**:
```
==> 0.5) Verificar conectividad con mirrors TUNA
Comprobando acceso a mirrors TUNA...
  - Mirror Debian principal: ✓ Accesible
  - Mirror Debian Security: ✓ Accesible
  - Mirror Docker CE: ✓ Accesible (trixie disponible)
  - Clave GPG de Docker: ✓ Accesible
✓ Todos los mirrors de TUNA están accesibles
```

**Ejemplo de resumen final**:
```
════════════════════════════════════════════════════════════════
                    RESUMEN DE INSTALACIÓN
════════════════════════════════════════════════════════════════

✓ Docker CE instalado y configurado exitosamente

📦 Componentes instalados:
   - docker-ce
   - docker-ce-cli
   - containerd.io
   - docker-buildx-plugin
   - docker-compose-plugin

🌐 Repositorios configurados:
   - Debian: mirrors.tuna.tsinghua.edu.cn/debian (trixie)
   - Docker CE: mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian (trixie)

🔑 Mirrors de Docker Hub configurados (para China):
   - https://docker.m.daocloud.io
   - https://hub-mirror.c.163.com
   - https://mirror.ccs.tencentyun.com
   - https://docker.mirrors.ustc.edu.cn

⚙️ Configuración del sistema:
   - IPv4 forwarding: Habilitado
   - Servicio Docker: Habilitado e iniciado
   - Socket Docker: Permisos configurados
   - Usuario 'tu_usuario': Agregado al grupo docker

⚠️  ACCIÓN REQUERIDA:
   Para que los permisos de Docker surtan efecto completamente:
   1. Cierra sesión completamente y vuelve a iniciar
      O ejecuta: newgrp docker
   2. Verifica que funcionó:
      groups
      docker ps
```
