# Script de Instalación de Docker CE en Debian 13 (Trixie)

## Descripción

Este script automatiza la instalación limpia de Docker CE en Debian 13 (Trixie), configurando los repositorios para usar el mirror TUNA de Tsinghua University (China) para mejorar la velocidad de descarga en regiones específicas. El script también realiza pruebas de funcionamiento (smoke tests) para verificar que Docker está correctamente instalado y configurado.

## Características

- **Limpieza previa**: Elimina cualquier instalación previa de Docker para evitar conflictos
- **Configuración de mirrors**: Cambia los repositorios de Debian y Docker al mirror TUNA
- **Instalación completa**: Instala Docker CE con todos los componentes necesarios
- **Configuración de red**: Habilita el forwarding IPv4 necesario para las redes bridge de Docker
- **Pruebas automáticas**: Ejecuta tests básicos para verificar la instalación

## Requisitos

- Sistema operativo: Debian 13 (Trixie)
- Permisos: Ejecutar como root o con sudo
- Conexión a Internet: Requerida para descargar paquetes y claves GPG

## Pasos del Script

### Paso 0: Preparación y Limpieza
- Crea el directorio `/etc/apt/keyrings` si no existe
- Elimina archivos de configuración previos de Docker (repositorios y claves GPG antiguas)

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
- Instala herramientas necesarias: `ca-certificates`, `curl`, `gnupg`, `lsb-release`
- Descarga la clave GPG oficial de Docker desde el sitio oficial
- Configura la clave en `/etc/apt/keyrings/docker.gpg` con permisos adecuados

### Paso 4: Repositorio Docker CE
- Detecta automáticamente el codename del sistema (debe ser "trixie")
- Configura el repositorio de Docker CE apuntando al mirror TUNA
- Actualiza los índices de paquetes con el nuevo repositorio

### Paso 5: Instalación de Docker CE
- Instala los siguientes paquetes:
  - `docker-ce`: Motor de Docker
  - `docker-ce-cli`: Interfaz de línea de comandos
  - `containerd.io`: Runtime de contenedores
  - `docker-buildx-plugin`: Plugin para builds avanzados
  - `docker-compose-plugin`: Plugin para Compose

### Paso 6: Configuración de Red
- Habilita el forwarding IPv4 necesario para que las redes bridge de Docker funcionen correctamente
- Configura `net.ipv4.ip_forward=1` en `/etc/sysctl.d/99-docker-forwarding.conf`
- Aplica la configuración con `sysctl --system`

### Paso 7: Habilitación del Servicio
- Habilita Docker para que se inicie automáticamente al arrancar el sistema
- Inicia el servicio Docker inmediatamente
- Verifica que el servicio esté corriendo correctamente

### Paso 8: Smoke Tests (Pruebas Rápidas)
El script ejecuta tres pruebas para verificar que todo funciona:

1. **Test hello-world**: Ejecuta el contenedor oficial `hello-world` para verificar que Docker puede ejecutar contenedores
2. **Inspección de red bridge**: Verifica que la red bridge predeterminada esté configurada y muestra la puerta de enlace
3. **Test de conectividad**: Ejecuta un contenedor Alpine Linux que:
   - Muestra la tabla de rutas del contenedor
   - Hace ping al DNS público chino (223.5.5.5) para verificar conectividad de red saliente

## Uso

```bash
# Dar permisos de ejecución
chmod +x scrip4.sh

# Ejecutar como root
sudo ./scrip4.sh

# O ejecutar directamente con bash como root
sudo bash scrip4.sh
```

## Manejo de Errores

El script incluye manejo de errores robusto:
- **Trap de errores**: Captura cualquier error y muestra la línea y comando que falló
- **Mensajes informativos**: Indica claramente qué paso está ejecutando
- **Mensajes de éxito**: Muestra un checkmark (✓) cuando cada paso se completa exitosamente
- **Mensajes de error**: Muestra mensajes claros si algún paso crítico falla
- **Salida inmediata**: El script se detiene en el primer error crítico (gracias a `set -euo pipefail`)

## Notas Importantes

- El script está diseñado específicamente para **Debian 13 (Trixie)**
- Usa el mirror **TUNA** de Tsinghua University para mejorar velocidades de descarga
- La clave GPG de Docker se descarga desde el sitio oficial (no del mirror) por seguridad
- Todos los pasos incluyen verificación de errores y mensajes informativos
- Los smoke tests verifican tanto la funcionalidad básica como la conectividad de red

## Resultado Esperado

Al finalizar exitosamente, deberías ver:
- Docker CE instalado y corriendo
- Servicio habilitado para iniciar automáticamente
- Todos los smoke tests pasando correctamente
- Mensaje final confirmando que todo está listo
```
