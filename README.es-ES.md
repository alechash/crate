

# Crate

Una interfaz de usuario nativa para macOS para gestionar contenedores de Linux utilizando el framework [Containerization](https://github.com/apple/containerization) de Apple. Sin Docker, sin Podman: solo Apple Silicon y Virtualization.framework.

![Swift](https://img.shields.io/badge/Swift-6-orange)
![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Características

- **Gestión del ciclo de vida del contenedor** — Crear, iniciar, detener, reiniciar y eliminar contenedores de Linux
- **Terminal integrada** — Acceder a la terminal de contenedores en ejecución directamente desde la app, con soporte para ventana independiente
- **Gestión de imágenes** — Descargar, inspeccionar y eliminar imágenes OCI desde cualquier registro
- **Redirección de puertos** — Mapear puertos desde tu Mac a contenedores de forma individual
- **Configuración de red** — Red basada en vmnet con ajustes personalizados de DNS y nombre de host
- **Volúmenes** — Almacenamiento persistente que sobrevive a los reinicios del contenedor
- **Registros en vivo** — Flujo de registros filtrable para todos los eventos del contenedor y del runtime
- **Configuración de contenedores** — Inspeccionar detalles y gestionar la redirección de puertos en contenedores en ejecución
- **Catálogo de descarga rápida** — Descarga con un clic para imágenes base comunes (Alpine, Ubuntu, Debian, Fedora, Nginx)

## Requisitos

- **macOS 26** (Tahoe) o posterior
- **Apple Silicon** (M1 o posterior)
- **Xcode 26+** con Swift 6
- El runtime de línea de comandos `container` debe estar instalado e iniciado:
  ```
  container system start
  ```

## Primeros pasos

### Compilar desde el código fuente

```bash
git clone https://github.com/alechash/crate.git
cd crate
open Crate/Crate.xcodeproj
```

Compila y ejecuta desde Xcode (Cmd+R). La aplicación requiere que el sandbox esté deshabilitado y utiliza el entitlement `com.apple.security.virtualization`.

### Primer lanzamiento

1. Asegúrate de que el runtime de contenedores esté ejecutándose (`container system start`)
2. Inicia Crate: la barra lateral mostrará "Runtime listo" con un punto verde una vez inicializado
3. Ve a **Imágenes** y descarga una imagen base, o utiliza las tarjetas de descarga rápida
4. Ve a **Contenedores**, haz clic en **+** para crear e iniciar un contenedor
5. Haz clic en el icono de terminal en un contenedor en ejecución para abrir una terminal

## Arquitectura

```
Crate/
├── CrateApp.swift                 # Punto de entrada de la app y grupos de ventanas
├── ContentView.swift              # Navegación raíz (barra lateral + detalle)
├── Models/
│   ├── ManagedContainer.swift     # Modelo de datos del contenedor
│   ├── ManagedImage.swift         # Modelo de datos de imagen
│   ├── LogEntry.swift             # Entrada de registro con filtrado por nivel
│   ├── ImageCatalog.swift         # Catálogo de imágenes de descarga rápida
│   ├── CrateVolume.swift          # Modelo de volumen persistente
│   ├── PortMapping.swift          # Modelo de redirección de puertos
│   └── CrateError.swift           # Tipos de error
├── Manager/
│   ├── CrateManager.swift         # Gestor principal del runtime (imágenes, contenedores, volúmenes, red)
│   └── PortForwarder.swift        # Proxy TCP para redirección de puertos (Network.framework)
├── Terminal/
│   ├── ContainerTerminalSession.swift  # Sesión de terminal con manejo de ANSI
│   ├── TerminalIO.swift           # Puente Writer/ReaderStream para E/S del contenedor
│   └── TerminalView.swift         # IU de terminal con historial, borrar y ventana independiente
└── Views/
    ├── ContainersView.swift       # Lista de contenedores
    ├── ContainerRow.swift         # Fila de contenedor con botones de acción
    ├── ContainerDetailView.swift  # Configuración del contenedor y panel de información
    ├── CreateContainerSheet.swift # Formulario de creación de contenedor (recursos, red, puertos, volúmenes)
    ├── ImagesView.swift           # Lista de imágenes con descarga y descarga rápida
    ├── VolumesView.swift          # Lista de volúmenes con creación/eliminación
    └── LogsView.swift             # Visor de registros con búsqueda y filtrado
```

## Cómo funciona

Crate utiliza directamente el framework Swift `Containerization` de Apple: **no** ejecuta la CLI `container` desde una terminal externa. Comparte el mismo almacenamiento de imágenes (`~/Library/Application Support/com.apple.container/`) y kernel, por lo que las imágenes descargadas vía CLI son visibles en Crate y viceversa.

Cada contenedor se ejecuta en su propia VM de Linux ligera a través de Virtualization.framework. La red utiliza `VmnetNetwork` para acceso a internet basado en NAT con DNS configurable. Los contenedores obtienen su propia IP en la subred local vmnet y son directamente accesibles desde tu Mac: la redirección de puertos mapea puertos de `localhost` a puertos de contenedor mediante un proxy TCP integrado.

## Configuración

Al crear un contenedor, puedes configurar:

| Configuración | Predeterminado |
|---|---|
| Imagen base | `docker.io/library/alpine:latest` |
| CPUs | 2 |
| Memoria | 1024 MB |
| Comandos | `sleep infinity` (admite múltiples comandos simultáneos) |
| Red | Habilitada |
| DNS | Gateway (automático) |
| Nombre de host | Generado automáticamente |
| Redirección de puertos | Ninguna (agrega mapeos de puertos host→contenedor según sea necesario) |
| Volúmenes | Ninguno (adjunta volúmenes persistentes en cualquier ruta de montaje) |

## Ejemplo rápido: Ejecutar Nginx

Inicia un servidor web Nginx y sirve una página personalizada desde tu Mac en `localhost:8080`.

1. **Inicia el runtime** (si aún no lo has hecho):
   ```bash
   container system start
   ```

2. **Inicia Crate** y espera el indicador verde "Runtime listo" en la barra lateral.

3. **Descarga la imagen de Nginx** — ve a **Imágenes** y haz clic en la tarjeta de descarga rápida **Nginx**, o descarga `docker.io/library/nginx:latest`.

4. **Crea el contenedor** — ve a **Contenedores**, haz clic en **+** y configura:
   - **Nombre:** `web`
   - **Imagen:** `docker.io/library/nginx:latest`
   - **Comandos:** `nginx -g 'daemon off;'` y `sleep infinity` (haz clic en "Agregar comando" para el segundo — múltiples comandos se ejecutan simultáneamente)
   - **Redirección de puertos:** agrega `8080 → 80`
   - Haz clic en **Crear e iniciar**

5. **Abre tu navegador** y accede a:
   ```
   http://localhost:8080
   ```
   Deberías ver la página "¡Bienvenido a nginx!".

6. **Personalízalo** — haz clic en el icono de terminal en el contenedor en ejecución:
   ```
   / # echo "Hello, Crate!" > /usr/share/nginx/html/index.html
   ```
   Recarga tu navegador: ahora deberías ver **Hello, Crate!**

7. **Limpia** — cierra la terminal, detén el contenedor y elimínalo. La redirección de puertos se limpia automáticamente al detenerse.

## Contribuir

Las contribuciones son bienvenidas. Para comenzar:

1. Haz un fork del repositorio
2. Crea una rama de características (`git checkout -b feature/my-feature`)
3. Realiza tus cambios y verifica que la compilación sea exitosa en Xcode
4. Envía un pull request

### Áreas donde se aprecia ayuda

- Monitoreo de recursos del contenedor (gráficos de CPU/memoria)
- Widget de acceso rápido en la barra de menú
- Presets y plantillas de contenedores
- Montajes de directorio (carpeta host → contenedor)
- Pruebas automatizadas

## Licencia

Licencia MIT — Copyright (c) Alec Wilson

Consulta [LICENSE](LICENSE) para más detalles.

## Agradecimientos

- [Framework Containerization de Apple](https://github.com/apple/containerization)
- [WWDC 2025: Conoce Containerization](https://developer.apple.com/videos/play/wwdc2025/346/)
