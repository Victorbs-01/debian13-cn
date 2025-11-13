sudo ./script5.sh juan*IMPORTANTE**: Después de ejecutar el script, los cambios de grupos NO surten efecto inmediatamente en la sesión actual. El usuario debe:

### Opción 1: Cerrar y volver a iniciar sesión (Recomendado)
- Cerrar sesión completamente
- Volver a iniciar sesión
- Los nuevos grupos estarán activos

### Opción 2: Usar newgrp (Temporal)h
# Para activar grupo sudo
newgrp sudo**Nota**: `newgrp` inicia una nueva shell, por lo que tendrás que salir con `exit` cuando termines.

## Flujo Completo Recomendado

### Paso 1: Configurar permisos del usuario
# Como root o con acceso sudo inicial
sudo ./script5.sh nombre_usuario### Paso 2: Usuario cierra sesión y vuelve a iniciar
El usuario debe cerrar sesión completamente y volver a iniciar para que los cambios surtan efecto.

### Paso 3: Instalar Docker
# Ahora el usuario puede ejecutar script4.sh con sudo
sudo ./script4.sh### Paso 4: (Opcional) Agregar usuario al grupo docker
Después de instalar Docker, puedes volver a ejecutar `script5.sh` para agregar al usuario al grupo docker, o modificar `script5.sh` para que también agregue al grupo docker si existe.

## Verificación

Después de reiniciar sesión, puedes verificar que los cambios funcionan:
ash
# Ver grupos del usuario actual
groups

# Verificar permisos sudo
sudo -l

# Probar ejecución con sudo
sudo whoami
# Debería mostrar: root## Manejo de Errores

El script incluye manejo de errores robusto:
- **Validación de permisos**: Verifica que se ejecuta como root
- **Validación de usuario**: Verifica que el usuario existe antes de intentar agregarlo
- **Trap de errores**: Captura cualquier error y muestra la línea y comando que falló
- **Mensajes informativos**: Indica claramente qué está haciendo en cada paso
- **Mensajes de éxito**: Muestra un checkmark (✓) cuando cada paso se completa exitosamente
- **Prevención de duplicados**: Evita agregar al usuario si ya está en el grupo

## Notas Importantes

- **Este script debe ejecutarse PRIMERO** antes de `script4.sh`
- El script debe ejecutarse como **root** o con **sudo** (necesitas acceso root inicial)
- Los cambios de grupos requieren **cerrar sesión y volver a iniciar** para surtir efecto
- Si el usuario ya está en el grupo sudo, el script no hace cambios y solo informa
- El script es seguro de ejecutar múltiples veces (idempotente)

## Relación con script4.sh

Este script es un **prerequisito** para `script4.sh`:

- **script5.sh** (PRIMERO): Da permisos sudo al usuario
- **script4.sh** (DESPUÉS): Instala Docker CE (requiere sudo)

**Orden correcto**:
1. Ejecutar `script5.sh nombre_usuario` como root/sudo inicial
2. Usuario cierra sesión y vuelve a iniciar
3. Usuario ejecuta `sudo ./script4.sh` para instalar Docker
4. (Opcional) Ejecutar `script5.sh` nuevamente para agregar al grupo docker

## Solución de Problemas

### Error: "El usuario no existe"
# Verificar usuarios disponibles
cut -d: -f1 /etc/passwd

# Crear usuario si es necesario
sudo adduser nombre_usuario
### Error: "Este script debe ejecutarse como root"
# Asegúrate de usar sudo
sudo ./script5.sh nombre_usuario

# O si tienes acceso directo como root
su -c "./script5.sh nombre_usuario"### Los grupos no se aplican después de reiniciar sesión
- Verifica que el usuario fue agregado: `groups nombre_usuario`
- Asegúrate de haber cerrado sesión completamente (no solo cerrar terminal)
- Prueba con `newgrp sudo` como alternativa temporal

### No tengo acceso root inicial
Si no tienes acceso root inicial, necesitas:
- Contactar al administrador del sistema
- O usar una cuenta que ya tenga permisos sudo
- O acceder directamente como root si es posible