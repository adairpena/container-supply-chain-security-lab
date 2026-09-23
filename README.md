# Proyecto de Seguridad de Imágenes con Trivy

Proyecto para analizar vulnerabilidades, generar reportes y documentar criterios de revisión de imágenes de contenedor con **Trivy**.

> Este proyecto forma parte de una práctica de seguridad de cadena de suministro de software.  
> En esta primera fase no se utiliza CI/CD: todo el proceso de análisis es **manual, reproducible y documentado**.

---

## 1. Objetivo

El objetivo de esta fase es utilizar Trivy para:

- Analizar vulnerabilidades conocidas en imágenes de contenedor.
- Generar reportes en formato JSON y HTML.
- Generar SBOM en formato CycloneDX.
- Ejecutar análisis manuales sobre imágenes locales o descargadas de un registry.
- Detectar secretos mediante el scanner de secretos.
- Documentar criterios para interpretar los resultados.
- Generar evidencias para controles de seguridad.

Las imágenes utilizadas en el Proyecto son:

```text
nginx:latest
python:3.4-alpine
debian:11
```

Adicionalmente se utiliza una imagen deliberadamente vulnerable:

```text
localhost/trivy-secret-demo:v1
```

para demostrar detección de secretos.

---

## 2. Arquitectura del Proyecto

El flujo de esta fase es:

```text
                    IMAGEN OCI
                        |
                        v
                     TRIVY
          +-------------+-------------+
          |             |             |
          v             v             v
 Vulnerabilidades      SBOM         Secretos
          |             |             |
          v             v             v
        JSON        CycloneDX        JSON
          |
          v
        HTML
          |
          v
  Evaluación manual
          |
     +----+----+
     |         |
     v         v
  Aceptar    Rechazar
```

Trivy no decide por sí mismo si una imagen debe desplegarse.  
El resultado técnico debe ser interpretado mediante un criterio de aceptación definido por la organización.

---

## 3. Requisitos

Proyecto utilizado:

- Linux Rocky/RHEL compatible.
- Podman.
- Trivy.
- `jq`.
- Acceso a Internet para descargar imágenes y actualizar la base de vulnerabilidades de Trivy.
- Usuario con privilegios suficientes para habilitar `podman.socket` cuando se analicen imágenes locales.

Comprobar Podman:

```bash
podman --version
```

Comprobar Trivy:

```bash
trivy --version
```

Comprobar `jq`:

```bash
jq --version
```

---

# 4. Instalación de Trivy

## 4.1 Crear el repositorio oficial

En Rocky Linux, RHEL o sistemas compatibles:

```bash
cat << 'EOF' | sudo tee /etc/yum.repos.d/trivy.repo
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://aquasecurity.github.io/trivy-repo/rpm/public.key
EOF
```

Actualizar la metadata:

```bash
sudo dnf makecache
```

Instalar Trivy:

```bash
sudo dnf install -y trivy
```

Validar instalación:

```bash
trivy --version
```

Referencia oficial:

```text
https://www.trivy.dev/docs/latest/getting-started/installation/
```

---

# 5. Preparar Podman para imágenes locales

Trivy puede analizar imágenes desde diferentes fuentes, incluyendo:

- Docker
- containerd
- Podman
- registries remotos

En este Proyecto se utiliza **Podman**.

Para analizar imágenes almacenadas localmente en Podman se habilita su socket:

```bash
sudo systemctl enable --now podman.socket
```

Validar:

```bash
systemctl status podman.socket --no-pager
```

Comprobar socket:

```bash
ls -l /run/podman/podman.sock
```

La ruta utilizada en este Proyecto es:

```text
/run/podman/podman.sock
```

Referencia oficial:

```text
https://trivy.dev/docs/dev/guide/target/container_image/
```

---

# 6. Descargar imágenes de prueba

Descargar Nginx:

```bash
podman pull nginx:latest
```

Descargar Python:

```bash
podman pull python:3.4-alpine
```

Descargar Debian:

```bash
podman pull debian:11
```

Comprobar:

```bash
podman images
```

---

# 7. Escaneo manual básico

El comando más simple es:

```bash
trivy image nginx:latest
```

Para forzar el uso de Podman:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  nginx:latest
```

Trivy descargará o actualizará su base de vulnerabilidades cuando sea necesario.

---

# 8. Escanear vulnerabilidades HIGH y CRITICAL

Para mostrar únicamente vulnerabilidades de severidad alta o crítica:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  python:3.4-alpine
```

Ejemplo observado durante el Proyecto:

```text
python:3.4-alpine
Total: 17
HIGH: 13
CRITICAL: 4
```

Además, Trivy identificó que la imagen utiliza una versión antigua de Alpine que ya no cuenta con soporte de seguridad.

> Una imagen funcional no necesariamente es una imagen segura.

---

# 9. Generar reporte JSON

Para Nginx:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --scanners vuln \
  --format json \
  --output reports/json/nginx_latest.json \
  nginx:latest
```

Para Python:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --scanners vuln \
  --format json \
  --output reports/json/python_3.4-alpine.json \
  python:3.4-alpine
```

Para Debian:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --scanners vuln \
  --format json \
  --output reports/json/debian_11.json \
  debian:11
```

---

# 10. Generar reportes HTML

La instalación RPM utilizada en este Proyecto incluye el template:

```text
/usr/local/share/trivy/templates/html.tpl
```

Comprobar:

```bash
ls -l /usr/local/share/trivy/templates/
```

Generar reporte HTML de Nginx:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --scanners vuln \
  --format template \
  --template "@/usr/local/share/trivy/templates/html.tpl" \
  --output reports/html/nginx_latest.html \
  nginx:latest
```

Python:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --scanners vuln \
  --format template \
  --template "@/usr/local/share/trivy/templates/html.tpl" \
  --output reports/html/python_3.4-alpine.html \
  python:3.4-alpine
```

Debian:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --scanners vuln \
  --format template \
  --template "@/usr/local/share/trivy/templates/html.tpl" \
  --output reports/html/debian_11.html \
  debian:11
```

Los tres reportes HTML son parte de los entregables del proyecto.

---

# 11. Generar SBOM CycloneDX

Trivy puede generar un inventario de componentes de software en formato CycloneDX.

Nginx:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --format cyclonedx \
  --output reports/sbom/nginx.cdx.json \
  nginx:latest
```

Python:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --format cyclonedx \
  --output reports/sbom/python34.cdx.json \
  python:3.4-alpine
```

Debian:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --format cyclonedx \
  --output reports/sbom/debian11.cdx.json \
  debian:11
```

Validar un SBOM:

```bash
jq . reports/sbom/nginx.cdx.json | head -50
```

---

# 12. Script para escaneo manual

El proyecto contiene:

```text
scripts/scan-image.sh
```

El script automatiza únicamente la ejecución manual de Trivy.  
No forma parte de un pipeline CI/CD.

Uso:

```bash
./scripts/scan-image.sh nginx:latest
```

También:

```bash
./scripts/scan-image.sh python:3.4-alpine
```

o:

```bash
./scripts/scan-image.sh debian:11
```

El script genera:

```text
reports/json/
reports/html/
reports/sbom/
reports/secrets/
```

Para habilitar su ejecución:

```bash
chmod 750 scripts/scan-image.sh
```

---

# 13. Procedimiento manual recomendado

Para analizar una nueva imagen:

## Paso 1. Obtener la imagen

```bash
podman pull <imagen>:<tag>
```

Ejemplo:

```bash
podman pull nginx:latest
```

## Paso 2. Confirmar que existe

```bash
podman images
```

## Paso 3. Ejecutar Trivy

```bash
./scripts/scan-image.sh <imagen>:<tag>
```

## Paso 4. Revisar reporte HTML

Abrir:

```text
reports/html/
```

## Paso 5. Revisar HIGH y CRITICAL

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  <imagen>:<tag>
```

## Paso 6. Revisar si existe versión corregida

Consultar las columnas:

```text
Installed Version
Fixed Version
Status
```

## Paso 7. Aplicar el criterio de aceptación

Registrar:

```text
CVE
Severidad
Paquete
Versión instalada
Versión corregida
Decisión
Responsable
Justificación
```

---

# 14. Cómo interpretar los resultados

Un reporte de Trivy puede incluir campos como:

| Campo | Significado |
|---|---|
| Vulnerability | Identificador de vulnerabilidad, normalmente CVE |
| Severity | Nivel de severidad |
| Library / Package | Componente vulnerable |
| Installed Version | Versión instalada en la imagen |
| Fixed Version | Versión que corrige la vulnerabilidad |
| Status | Estado conocido de la vulnerabilidad |
| Title | Descripción resumida |

## Severidades

### CRITICAL

Representa hallazgos de máxima prioridad.

No significa automáticamente que la vulnerabilidad sea explotable en el contexto específico de la aplicación, pero debe investigarse inmediatamente.

### HIGH

Vulnerabilidad de alta severidad.

Debe evaluarse antes de aprobar el artefacto para despliegue.

### MEDIUM

Normalmente requiere seguimiento y planificación de remediación.

### LOW

Debe mantenerse inventariada y revisarse según la política definida.

### UNKNOWN

Trivy dispone del hallazgo pero no cuenta con una severidad suficiente o normalizada para clasificarlo.

---

# 15. Fixed Version

Uno de los campos más importantes es:

```text
Fixed Version
```

Ejemplo:

```text
Installed Version: 1.0.6-r6
Fixed Version:     1.0.6-r7
```

Esto significa que existe una versión conocida del paquete que contiene una corrección.

El tratamiento puede ser:

```text
actualizar imagen base
        |
        v
actualizar dependencia
        |
        v
reconstruir imagen
        |
        v
volver a ejecutar Trivy
```

---

# 16. Criterio de aceptación del Proyecto

El criterio definido para este proyecto es:

| Severidad | Fix disponible | Acción |
|---|---|---|
| CRITICAL | Sí | RECHAZAR |
| HIGH | Sí | RECHAZAR |
| CRITICAL | No | Evaluación de riesgo |
| HIGH | No | Evaluación de riesgo |
| MEDIUM | Sí/No | Registrar y planificar |
| LOW | Sí/No | Registrar |

Este criterio es un ejemplo para el Proyecto y debe adaptarse al contexto y política de riesgo de cada organización.

Trivy identifica vulnerabilidades; **la decisión de riesgo sigue siendo responsabilidad de la organización**.

---

# 17. Imagen fuera de soporte

Durante las pruebas se utilizó:

```text
python:3.4-alpine
```

Trivy informó que la distribución base detectada era una versión antigua de Alpine sin soporte de seguridad.

Esto es relevante porque una vulnerabilidad puede:

```text
existir
   |
   v
no tener corrección
   |
   v
porque el sistema base está EOL
```

En estos casos la solución normalmente no consiste en corregir paquetes individuales sino en:

```text
actualizar la imagen base
        |
        v
reconstruir
        |
        v
volver a escanear
```

---

# 18. Secret scanning

Trivy también puede analizar secretos.

En este Proyecto se creó una imagen deliberadamente vulnerable:

```text
localhost/trivy-secret-demo:v1
```

El secreto utilizado es completamente ficticio.

Escaneo:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --scanners secret \
  --secret-config ./demo-secret/trivy-secret.yaml \
  localhost/trivy-secret-demo:v1
```

Resultado observado:

```text
/app/config.txt

Total: 1
CRITICAL: 1

demo-secret
Credencial ficticia del proyecto
```

La evidencia JSON se genera mediante:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --scanners secret \
  --secret-config ./demo-secret/trivy-secret.yaml \
  --format json \
  --output ./reports/secrets/trivy-secret-demo-v1.json \
  localhost/trivy-secret-demo:v1
```

---

# 19. Demostración de capas OCI

Se creó posteriormente:

```text
localhost/trivy-secret-demo:v2
```

Esta versión elimina:

```text
/app/config.txt
```

en una capa posterior.

Comprobación:

```bash
podman run --rm \
  localhost/trivy-secret-demo:v2 \
  sh -c 'test -f /app/config.txt && echo EXISTE || echo NO_EXISTE'
```

Resultado:

```text
NO_EXISTE
```

Sin embargo:

```bash
podman history \
  --no-trunc \
  localhost/trivy-secret-demo:v2 \
  | grep -E 'DEMO_SECRET|config.txt'
```

permite observar tanto la capa que introdujo el secreto como la capa posterior que elimina el archivo.

Esto demuestra por qué una credencial no debe incorporarse a una imagen pensando que eliminarla en otro `RUN` resuelve el problema.

---

# 20. Buenas prácticas

- No usar `latest` para artefactos productivos sin control adicional.
- Mantener actualizadas las imágenes base.
- Escanear nuevamente después de modificar dependencias.
- Revisar especialmente vulnerabilidades HIGH y CRITICAL.
- No ignorar vulnerabilidades únicamente para obtener un reporte "limpio".
- Documentar cualquier excepción.
- No almacenar secretos en Dockerfile/Containerfile.
- No incluir credenciales dentro de layers.
- Mantener los reportes asociados a la imagen y versión analizadas.
- Conservar la fecha del análisis.
- Mantener una persona o equipo responsable de revisar resultados.
- Reanalizar periódicamente imágenes que continúen desplegadas.

---

# 21. Frecuencia recomendada

Para este Proyecto se documenta el siguiente esquema:

```text
Nueva imagen
    -> escaneo obligatorio

Nueva versión de aplicación
    -> escaneo obligatorio

Cambio de imagen base
    -> escaneo obligatorio

Vulnerabilidad crítica relevante
    -> reescaneo extraordinario

Imágenes que permanezcan en uso
    -> reescaneo periódico
```

Una herramienta de análisis no sustituye el proceso de gestión de vulnerabilidades.

---

# 22. Estructura del proyecto

```text
proyecto-trivy-cosign/
|
├── README.md
├── .gitignore
|
├── scripts/
│   └── scan-image.sh
|
├── reports/
│   ├── html/
│   ├── json/
│   ├── sbom/
│   └── secrets/
|
├── demo-secret/
│   ├── Containerfile
│   └── trivy-secret.yaml
|
├── evidence/
│   └── trivy/
|
└── keys/
```

> La carpeta `keys/` se utilizará posteriormente en la fase de Cosign.  
> Las claves privadas nunca deben almacenarse en Git.

---

# 23. Evidencias generadas

## Vulnerabilidades

```text
reports/json/
```

## Reportes HTML

```text
reports/html/
```

Se generan reportes de al menos:

```text
nginx:latest
python:3.4-alpine
debian:11
```

## SBOM

```text
reports/sbom/
```

Formato:

```text
CycloneDX JSON
```

## Secret scanning

```text
reports/secrets/
```

## Evidencia adicional

```text
evidence/trivy/
```

---

# 24. Troubleshooting

## Error: no podman socket found

Ejemplo:

```text
unable to initialize Podman client:
no podman socket found
```

Habilitar:

```bash
sudo systemctl enable --now podman.socket
```

Comprobar:

```bash
ls -l /run/podman/podman.sock
```

Utilizar explícitamente:

```bash
--podman-host /run/podman/podman.sock
```

---

## Error: unable to write results

Verificar el directorio actual:

```bash
pwd
```

Los comandos de este documento asumen que se ejecutan desde la raíz:

```text
/home/adair/proyecto-trivy-cosign
```

Crear directorios:

```bash
mkdir -p reports/{json,html,sbom,secrets}
```

---

## Trivy no encuentra una imagen local

Comprobar:

```bash
podman images
```

Después usar:

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  <imagen>
```

---

# 25. Relación con ISO/IEC 27001:2022

Esta fase genera evidencia principalmente para:

### A.8.8 - Gestión de vulnerabilidades técnicas

Evidencia:

- reportes de vulnerabilidades;
- clasificación de severidad;
- tratamiento documentado;
- reescaneo.

### A.8.29 - Pruebas de seguridad en desarrollo y aceptación

Evidencia:

- criterio de aceptación;
- análisis previo al despliegue;
- decisión documentada.

### A.5.9 - Inventario de información y activos asociados

Evidencia:

- SBOM CycloneDX de las imágenes.

### A.8.12 - Prevención de fuga de datos

Evidencia:

- secret scanning;
- imagen deliberadamente vulnerable;
- demostración de persistencia de datos en capas OCI.

---

# 26. Alcance actual

Esta fase cubre exclusivamente **Trivy**.

Fases posteriores del proyecto:

```text
Trivy
   |
   v
Cosign
   |
   v
Connaisseur
   |
   v
Kubernetes admission control
```

No se utiliza CI/CD porque el objetivo del Proyecto es comprender y documentar el proceso manual.

---

# 27. Referencias

- Aqua Security. Trivy - Installation.  
  https://www.trivy.dev/docs/latest/getting-started/installation/

- Aqua Security. Trivy - Container Image.  
  https://trivy.dev/docs/dev/guide/target/container_image/

- Aqua Security. Trivy CLI - Image.  
  https://trivy.dev/docs/dev/references/configuration/cli/trivy_image/

- Aqua Security. Trivy Documentation.  
  https://trivy.dev/

---

## Estado

```text
Fase 1 - Trivy: completada
Fase 2 - Cosign: pendiente
Fase 3 - Connaisseur: pendiente
```
