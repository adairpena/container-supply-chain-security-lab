# Proyecto de Seguridad de Cadena de Suministro de Imágenes

Laboratorio práctico para analizar, documentar y controlar la seguridad de imágenes de contenedor antes de su despliegue en Kubernetes.

El proyecto se desarrolla de forma **manual, reproducible y documentada**, sin integración CI/CD, con tres componentes principales:

- **Trivy**: escaneo de vulnerabilidades, generación de reportes, SBOM y detección de secretos.
- **Connaisseur**: admission controller para aplicar políticas de confianza antes de crear workloads en Kubernetes.
- **Cosign**: firma y verificación criptográfica de imágenes. Esta fase se encuentra pendiente y se integrará posteriormente con Connaisseur.

> El objetivo del laboratorio es comprender cada control de forma independiente antes de automatizarlo.

---

## Estado del proyecto

| Fase | Estado | Evidencia principal |
|---|---|---|
| Trivy | ✅ Completada | JSON, HTML, SBOM, secret scanning y análisis de capas |
| Connaisseur base | ✅ Completada | Helm, webhook, namespace protegido, ACCEPT/DENY y trust pinning |
| Cosign | ✅ Completadae | Par de claves, firma y verificación manual |
| Integración Cosign + Connaisseur | ⏳ Pendiente | Validación con `cosign.pub` y demos con imágenes propias |

---

## Arquitectura general

```text
                         IMAGEN OCI
                             |
                 +-----------+-----------+
                 |                       |
                 v                       v
               TRIVY                   COSIGN
                 |                       |
        +--------+--------+              |
        |        |        |              |
        v        v        v              v
      CVEs      SBOM   Secretos        Firma
        |                               |
        v                               v
 Evaluación manual                  Registry OCI
        |                               |
        +---------------+---------------+
                        |
                        v
                  Kubernetes API
                        |
                        v
                  CONNAISSEUR
                        |
                  +-----+-----+
                  |           |
                  v           v
                ACCEPT       DENY
                  |           |
                  v           X
            Workload creado  Bloqueado
```

Actualmente el flujo Trivy y el enforcement base de Connaisseur están implementados. La firma propia con Cosign se integrará en la siguiente fase.

---

## Estructura actual del repositorio

```text
proyecto-trivy-cosign/
├── README.md
├── .gitignore
├── demo-secret/
│   ├── Containerfile
│   └── trivy-secret.yaml
├── docs/
├── evidence/
│   ├── trivy/
│   └── connaisseur/
├── k8s-ansible/
├── keys/
├── kubernetes/
│   └── connaisseur/
│       └── values.yaml
├── reports/
│   ├── html/
│   ├── json/
│   ├── sbom/
│   └── secrets/
└── scripts/
    └── scan-image.sh
```

> `keys/` está reservada para la fase Cosign. Las claves privadas no deben versionarse.

---


## Fase 1 — Trivy: vulnerabilidades, SBOM y secretos

Proyecto para analizar vulnerabilidades, generar reportes y documentar criterios de revisión de imágenes de contenedor con **Trivy**.

> Este proyecto forma parte de una práctica de seguridad de cadena de suministro de software.
> En esta primera fase no se utiliza CI/CD: todo el proceso de análisis es **manual, reproducible y documentado**.

---

#### 1. Objetivo

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

#### 2. Arquitectura del Proyecto

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

#### 3. Requisitos

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

### 4. Instalación de Trivy

#### 4.1 Crear el repositorio oficial

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

### 5. Preparar Podman para imágenes locales

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

### 6. Descargar imágenes de prueba

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

### 7. Escaneo manual básico

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

### 8. Escanear vulnerabilidades HIGH y CRITICAL

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

### 9. Generar reporte JSON

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

### 10. Generar reportes HTML

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

### 11. Generar SBOM CycloneDX

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

### 12. Script para escaneo manual

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

### 13. Procedimiento manual recomendado

Para analizar una nueva imagen:

#### Paso 1. Obtener la imagen

```bash
podman pull <imagen>:<tag>
```

Ejemplo:

```bash
podman pull nginx:latest
```

#### Paso 2. Confirmar que existe

```bash
podman images
```

#### Paso 3. Ejecutar Trivy

```bash
./scripts/scan-image.sh <imagen>:<tag>
```

#### Paso 4. Revisar reporte HTML

Abrir:

```text
reports/html/
```

#### Paso 5. Revisar HIGH y CRITICAL

```bash
trivy image \
  --podman-host /run/podman/podman.sock \
  --image-src podman \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  <imagen>:<tag>
```

#### Paso 6. Revisar si existe versión corregida

Consultar las columnas:

```text
Installed Version
Fixed Version
Status
```

#### Paso 7. Aplicar el criterio de aceptación

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

### 14. Cómo interpretar los resultados

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

#### Severidades

##### CRITICAL

Representa hallazgos de máxima prioridad.

No significa automáticamente que la vulnerabilidad sea explotable en el contexto específico de la aplicación, pero debe investigarse inmediatamente.

##### HIGH

Vulnerabilidad de alta severidad.

Debe evaluarse antes de aprobar el artefacto para despliegue.

##### MEDIUM

Normalmente requiere seguimiento y planificación de remediación.

##### LOW

Debe mantenerse inventariada y revisarse según la política definida.

##### UNKNOWN

Trivy dispone del hallazgo pero no cuenta con una severidad suficiente o normalizada para clasificarlo.

---

### 15. Fixed Version

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

### 16. Criterio de aceptación del Proyecto

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

### 17. Imagen fuera de soporte

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

### 18. Secret scanning

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

### 19. Demostración de capas OCI

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

### 20. Buenas prácticas

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

### 21. Frecuencia recomendada

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

### 22. Estructura del proyecto

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

### 23. Evidencias generadas

#### Vulnerabilidades

```text
reports/json/
```

#### Reportes HTML

```text
reports/html/
```

Se generan reportes de al menos:

```text
nginx:latest
python:3.4-alpine
debian:11
```

#### SBOM

```text
reports/sbom/
```

Formato:

```text
CycloneDX JSON
```

#### Secret scanning

```text
reports/secrets/
```

#### Evidencia adicional

```text
evidence/trivy/
```

---

### 24. Troubleshooting

#### Error: no podman socket found

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

#### Error: unable to write results

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

#### Trivy no encuentra una imagen local

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

### 25. Relación con ISO/IEC 27001:2022

Esta fase genera evidencia principalmente para:

##### A.8.8 - Gestión de vulnerabilidades técnicas

Evidencia:

- reportes de vulnerabilidades;
- clasificación de severidad;
- tratamiento documentado;
- reescaneo.

##### A.8.29 - Pruebas de seguridad en desarrollo y aceptación

Evidencia:

- criterio de aceptación;
- análisis previo al despliegue;
- decisión documentada.

##### A.5.9 - Inventario de información y activos asociados

Evidencia:

- SBOM CycloneDX de las imágenes.

##### A.8.12 - Prevención de fuga de datos

Evidencia:

- secret scanning;
- imagen deliberadamente vulnerable;
- demostración de persistencia de datos en capas OCI.

---

---

## Fase 2 — Cosign: Firma y verificación criptográfica de imagenes
En esta sección se describe la instalacion y uso básico de la herramienta para asegurar la integridad de una imagen para contenedores.

### 1. Objetivo
- Instalar Cosign.
- Generar un par de claves pública/privada.
- Proteger la llave privada y documentar su custodia.
- Firmar manualmente al menos tres imágenes.
- Verificar manualmente las firmas.
- Publicar las imágenes en un registry OCI accesible por Kubernetes.
- Configurar Connaisseur para confiar en la clave pública propia.
- Demostrar:
  - imagen propia firmada → `ACCEPT`;
  - imagen propia sin firma válida → `DENY`.

Flujo previsto:

```text
Imagen propia
    |
    v
Cosign
    |
    +-- cosign.key   (privada, NO Git)
    |
    v
Registry OCI
    |
    v
Connaisseur
    |
    +-- cosign.pub (public key)
    |
    +---------+---------+
    |                   |
    v                   v
Firma válida       Firma inválida
    |                   |
    v                   v
 ACCEPT               DENY
```

## 2. Instalación de Cosign

Descarga e instala el RPM oficial desde el repositorio de Sigstore.

```bash
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign
```

Se puede verificar instalación mediante:
```bash
cosign version
```

## 3. Generación de llaves
Se crea carpeta keys:
```bash
mkdir -p keys
cd keys
cosign generate-key-pair
cd ..     #Regresamos un nivel arriba
```
Esto genera cosign.pub y cosign.key

## 4. Preparando un Registry local para subir imagenes localmente
Se levanta un registro local en el puerto 5000 para poder subir y firmar las imágenes sin crear cuentas.
```bash
podman run -d -p 5000:5000 --name local-registry docker.io/library/registry:2
```

Se etiquetan las imagenes
```bash
podman tag nginx:latest localhost:5000/nginx:local
podman tag python:3.4-alpine localhost:5000/python:local
podman tag debian:11 localhost:5000/debian:local
```

Push a las imagenes omitiendo tls
```bash
podman push --tls-verify=false localhost:5000/nginx:local
podman push --tls-verify=false localhost:5000/python:local
podman push --tls-verify=false localhost:5000/debian:local
```

## 5. Firmado local de imagenes
Firma las 3 imágenes utilizando la llave privada. Como usamos un registro local sin HTTPS, necesitamos la bandera --allow-insecure-registry.
```bash
cosign sign --key keys/cosign.key localhost:5000/nginx:local --allow-insecure-registry -y
cosign sign --key keys/cosign.key localhost:5000/python:local --allow-insecure-registry -y
cosign sign --key keys/cosign.key localhost:5000/debian:local --allow-insecure-registry -y
```

## 6. Verificacion de firmas
```bash
cosign verify --key keys/cosign.pub localhost:5000/nginx:local --allow-insecure-registry
cosign verify --key keys/cosign.pub localhost:5000/python:local --allow-insecure-registry
cosign verify --key keys/cosign.pub localhost:5000/debian:local --allow-insecure-registry
```
Interpretación de la salida:
Si la verificación es exitosa, Cosign retornará un objeto JSON indicando que la firma es válida y los detalles del digest de la imagen que fue firmada. Si la imagen es alterada o carece de firma, el comando fallará y devolverá un código de error, bloqueando así un posible despliegue inseguro.

Salida exitosa:
```bash
Verification for localhost:5000/debian:local --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The signatures were verified against the specified public key

[{"critical":{"identity":{"docker-reference":"localhost:5000/debian:local"},"image":{"docker-manifest-digest":"sha256:8ebee6093968f540c7f36dbf7a1dc13393e66f08d5452233e1bac0382e170bcc"},"type":"https://sigstore.dev/cosign/sign/v1"},"optional":{}}]
```

Salida erronea, si se sube una imagen sin firmar:
```bash
Error: no signatures found
error during command execution: no signatures found
```

Salida erronea donde si esta firmada pero no con la llave correcta:
```bash
mkdir -p keys_false && cd keys_false
cosign generate-key-pair
Enter password for private key:
Enter password for private key again:
Private key written to cosign.key
Public key written to cosign.pub
cd ..
cosign verify --key keys_false/cosign.pub localhost:5000/nginx:local --allow-insecure-registry
Error: no matching attestations: failed to verify log inclusion: transparency log certificate does not match
failed to verify log inclusion: transparency log certificate does not match
error during command execution: no matching attestations: failed to verify log inclusion: transparency log certificate does not match
failed to verify log inclusion: transparency log certificate does not match
```

## Fase 3 — Connaisseur: admission control en Kubernetes

Este documento describe la instalación, configuración y validación de **Connaisseur** como admission controller para verificar la confianza de imágenes de contenedor antes de permitir su despliegue en Kubernetes.

La configuración documentada corresponde al laboratorio realizado con:

- Kubernetes `v1.36.4`
- Helm `v3.22.0`
- Connaisseur Chart `2.13.0`
- Connaisseur App `3.13.0`
- Runtime: `containerd`
- CNI: `Flannel`
- Namespace de pruebas: `supply-chain-demo`

> Esta fase demuestra el funcionamiento del admission controller con la configuración de prueba incluida por Connaisseur. La integración con una clave propia de **Cosign** se realizará en una fase posterior.

---

### 1. Objetivo

El objetivo de esta fase es implementar un control de admisión en Kubernetes que permita:

- Instalar Connaisseur mediante Helm.
- Configurar validación de imágenes por namespace.
- Interceptar solicitudes `CREATE` y `UPDATE`.
- Aceptar imágenes cuya firma sea válida y confiable.
- Rechazar imágenes que no cumplan con la política de confianza.
- Demostrar *trust pinning* mediante referencias por digest SHA-256.
- Generar evidencia técnica del proceso.

Flujo general:

```text
Usuario
   |
   v
kubectl apply / kubectl run
   |
   v
Kubernetes API Server
   |
   v
Connaisseur Admission Webhook
   |
   +---------------------------+
   |                           |
   v                           v
Firma válida              Firma no válida
   |                           |
   v                           v
ACCEPT                        DENY
   |                           |
   v                           X
Pod creado                Pod no creado
```

---

### 2. Prerrequisitos

Antes de instalar Connaisseur se validó que el clúster Kubernetes estuviera operativo.

#### 2.1 Validar nodos

```bash
kubectl get nodes -o wide
```

Resultado esperado:

```text
NAME       STATUS   ROLES           VERSION
master01   Ready    control-plane   v1.36.4
worker02   Ready    <none>          v1.36.4
```

#### 2.2 Validar Pods del sistema

```bash
kubectl get pods -A
```

Los componentes principales deben encontrarse en estado `Running`.

#### 2.3 Validar red y DNS

```bash
kubectl run dns-test   -n supply-chain-demo   --image=busybox:1.36   --restart=Never   -- sleep 3600
```

```bash
kubectl exec   -n supply-chain-demo   dns-test --   nslookup kubernetes.default.svc.cluster.local
```

Resultado esperado:

```text
Server:    10.96.0.10
Address:   10.96.0.10:53

Name:      kubernetes.default.svc.cluster.local
Address:   10.96.0.1
```

---

### 3. Instalación de Helm

Verificar:

```bash
helm version
```

Versión utilizada:

```text
v3.22.0
```

Validar comunicación con Kubernetes:

```bash
helm list -A
```

---

### 4. Agregar el repositorio de Connaisseur

```bash
helm repo add connaisseur   https://sse-secure-systems.github.io/connaisseur/charts
```

```bash
helm repo update
```

```bash
helm repo list
```

Resultado esperado:

```text
NAME          URL
connaisseur   https://sse-secure-systems.github.io/connaisseur/charts
```

Buscar el chart:

```bash
helm search repo connaisseur
```

Versión utilizada:

```text
CHART VERSION: 2.13.0
APP VERSION:   3.13.0
```

---

### 5. Descargar el chart para revisión

```bash
mkdir -p /tmp/connaisseur-chart
```

```bash
helm pull connaisseur/connaisseur   --version 2.13.0   --untar   --untardir /tmp/connaisseur-chart
```

Verificar:

```bash
ls -la /tmp/connaisseur-chart/connaisseur
```

Debe contener:

```text
Chart.yaml
values.yaml
templates/
README.md
```

---

### 6. Configuración de validación por namespace

Archivo:

```text
kubernetes/connaisseur/values.yaml
```

Contenido:

```yaml
application:
  features:
    namespacedValidation:
      mode: validate
```

Con esta configuración, Connaisseur solo valida namespaces que tengan la etiqueta:

```text
securesystemsengineering.connaisseur/webhook=validate
```

---

### 7. Validar el chart antes de instalarlo

#### 7.1 Helm lint

```bash
helm lint /tmp/connaisseur-chart/connaisseur   -f /home/adair/proyecto-trivy-cosign/kubernetes/connaisseur/values.yaml
```

Resultado obtenido:

```text
1 chart(s) linted, 0 chart(s) failed
```

#### 7.2 Renderizar manifiestos

```bash
helm template connaisseur   /tmp/connaisseur-chart/connaisseur   --namespace connaisseur   -f /home/adair/proyecto-trivy-cosign/kubernetes/connaisseur/values.yaml   > /tmp/connaisseur-rendered.yaml
```

> El archivo renderizado puede contener Secrets, certificados y material generado por el chart. No debe subirse al repositorio Git.

Después de revisarlo:

```bash
rm -f /tmp/connaisseur-rendered.yaml
```

---

### 8. Configurar kubeconfig para administración

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
```

Validar:

```bash
kubectl get nodes
```

---

### 9. Instalación de Connaisseur

```bash
helm upgrade --install connaisseur   /tmp/connaisseur-chart/connaisseur   --namespace connaisseur   --create-namespace   --atomic   --timeout 10m   -f /home/adair/proyecto-trivy-cosign/kubernetes/connaisseur/values.yaml
```

Resultado esperado:

```text
STATUS: deployed
```

Validar:

```bash
helm list -n connaisseur
```

Resultado del laboratorio:

```text
NAME          NAMESPACE     STATUS     CHART                APP VERSION
connaisseur   connaisseur   deployed   connaisseur-2.13.0   3.13.0
```

---

### 10. Verificación de Pods

```bash
kubectl get pods -n connaisseur -o wide
```

Resultado observado:

```text
connaisseur-...               1/1 Running
connaisseur-...               1/1 Running
connaisseur-...               1/1 Running
connaisseur-redis-...         1/1 Running
```

---

### 11. Verificación de Services

```bash
kubectl get svc -n connaisseur
```

Servicios observados:

```text
connaisseur-svc
connaisseur-redis-service
```

El servicio principal expone el webhook en `443/TCP`.

---

### 12. Admission Webhook

La versión utilizada instala una:

```text
MutatingWebhookConfiguration
```

Verificar:

```bash
kubectl get mutatingwebhookconfigurations
```

Resultado:

```text
NAME                  WEBHOOKS
connaisseur-webhook   1
```

Consultar configuración:

```bash
kubectl get mutatingwebhookconfiguration   connaisseur-webhook   -o yaml
```

Aspectos importantes:

```yaml
failurePolicy: Fail
```

El webhook apunta a:

```text
Service:   connaisseur-svc
Namespace: connaisseur
Path:      /mutate
Port:      443
```

Intercepta operaciones `CREATE` y `UPDATE` sobre:

```text
Pods
Deployments
ReplicaSets
DaemonSets
StatefulSets
Jobs
CronJobs
ReplicationControllers
```

---

### 13. Namespace Selector

La configuración generada contiene:

```yaml
namespaceSelector:
  matchExpressions:
    - key: securesystemsengineering.connaisseur/webhook
      operator: In
      values:
        - validate
```

Esto limita el enforcement a namespaces etiquetados.

---

### 14. Habilitar validación en el namespace de laboratorio

```bash
kubectl label namespace supply-chain-demo   securesystemsengineering.connaisseur/webhook=validate   --overwrite
```

Validar:

```bash
kubectl get namespace supply-chain-demo --show-labels
```

Resultado:

```text
securesystemsengineering.connaisseur/webhook=validate
```

Estrategia:

```text
kube-system       -> no validado
kube-flannel      -> no validado
connaisseur       -> no validado

supply-chain-demo -> validado
```

---

### 15. Demo: imagen firmada aceptada

Imagen utilizada:

```text
docker.io/securesystemsengineering/testimage:signed
```

Crear Pod:

```bash
kubectl run signed-demo   -n supply-chain-demo   --image=docker.io/securesystemsengineering/testimage:signed
```

Resultado:

```text
pod/signed-demo created
```

Validar:

```bash
kubectl get pod signed-demo   -n supply-chain-demo   -o wide
```

Resultado del laboratorio:

```text
NAME          READY   STATUS    NODE
signed-demo   1/1     Running   worker02
```

---

### 16. Trust Pinning

Consultar la referencia final:

```bash
kubectl get pod signed-demo   -n supply-chain-demo   -o jsonpath='{.spec.containers[0].image}{"\n"}'
```

Resultado:

```text
index.docker.io/securesystemsengineering/testimage:signed@sha256:fe542477b92fb84c38eda9c824f6566d5c2536ef30af9c47152fa8a5fadb58dd
```

Aunque se solicitó un tag, el objeto quedó asociado a un digest SHA-256 concreto.

---

### 17. Demo: imagen sin firma válida rechazada

Imagen utilizada:

```text
docker.io/securesystemsengineering/testimage:unsigned
```

Ejecutar:

```bash
kubectl run unsigned-demo   -n supply-chain-demo   --image=docker.io/securesystemsengineering/testimage:unsigned
```

Resultado obtenido:

```text
Error from server:
admission webhook "connaisseur-svc.connaisseur.svc"
denied the request:
error during notaryv1 validation of image
docker.io/securesystemsengineering/testimage:unsigned:
validated targets don't contain reference:
no tag 'unsigned' found in targets
```

Confirmar que el Pod no existe:

```bash
kubectl get pod unsigned-demo   -n supply-chain-demo
```

Resultado:

```text
Error from server (NotFound):
pods "unsigned-demo" not found
```

---

### 18. Logs de validación

```bash
kubectl logs   -n connaisseur   -l app.kubernetes.io/name=connaisseur   --tail=100
```

Para la imagen firmada se observó:

```text
successfully validated image docker.io/securesystemsengineering/testimage:signed
using rule docker.io/securesystemsengineering/*:*
and validator dockerhub
```

Para la imagen no firmada:

```text
error validating Pod unsigned-demo:
error during notaryv1 validation
```

---

### 19. Evidencias generadas

Las evidencias se almacenan en:

```text
evidence/connaisseur/
```

Archivos:

```text
helm-release.txt
connaisseur-pods.txt
connaisseur-webhook.yaml
namespace-validation.txt
helm-values.txt
signed-accepted.txt
signed-image-reference.txt
unsigned-rejected.txt
validation-logs.txt
```

Ejemplos:

```bash
helm list -n connaisseur   > evidence/connaisseur/helm-release.txt
```

```bash
kubectl get pods -n connaisseur -o wide   > evidence/connaisseur/connaisseur-pods.txt
```

```bash
kubectl get mutatingwebhookconfiguration connaisseur-webhook -o yaml   > evidence/connaisseur/connaisseur-webhook.yaml
```

```bash
kubectl get namespace supply-chain-demo --show-labels   > evidence/connaisseur/namespace-validation.txt
```

```bash
kubectl get pod signed-demo   -n supply-chain-demo   -o wide   > evidence/connaisseur/signed-accepted.txt
```

```bash
kubectl get pod signed-demo   -n supply-chain-demo   -o jsonpath='{.spec.containers[0].image}{"\n"}'   > evidence/connaisseur/signed-image-reference.txt
```

```bash
kubectl run unsigned-demo   -n supply-chain-demo   --image=docker.io/securesystemsengineering/testimage:unsigned   > evidence/connaisseur/unsigned-rejected.txt 2>&1 || true
```

---

### 20. Troubleshooting

#### `repo connaisseur not found`

El repositorio Helm fue agregado con otro usuario.

```bash
helm repo add connaisseur   https://sse-secure-systems.github.io/connaisseur/charts
```

```bash
helm repo update
```

---

#### `helm lint` busca `Chart.yaml` local

`helm lint` debe ejecutarse contra un chart local:

```bash
helm pull connaisseur/connaisseur   --version 2.13.0   --untar   --untardir /tmp/connaisseur-chart
```

```bash
helm lint /tmp/connaisseur-chart/connaisseur   -f /home/adair/proyecto-trivy-cosign/kubernetes/connaisseur/values.yaml
```

---

#### kubectl intenta usar `localhost:8080`

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
```

```bash
kubectl get nodes
```

---

#### No aparece `ValidatingWebhookConfiguration`

En esta versión del chart se utiliza:

```text
MutatingWebhookConfiguration
```

Consultar:

```bash
kubectl get mutatingwebhookconfigurations
```

---

#### El Pod no es validado

Verificar la etiqueta del namespace:

```bash
kubectl get namespace supply-chain-demo --show-labels
```

Debe contener:

```text
securesystemsengineering.connaisseur/webhook=validate
```

---

### 21. Consideraciones de seguridad

#### Failure Policy

El webhook utiliza:

```text
failurePolicy: Fail
```

En un namespace protegido, si Connaisseur no puede completar la validación, Kubernetes bloquea la operación.

Esto representa un comportamiento de tipo:

```text
fail closed
```

#### Validación limitada por namespace

Durante el laboratorio no se habilitó enforcement global.

El namespace protegido es:

```text
supply-chain-demo
```

#### No versionar secretos generados

No subir a Git:

```text
/tmp/connaisseur-rendered.yaml
```

porque puede contener:

- claves TLS;
- certificados;
- passwords generados;
- Secrets de Kubernetes.

---

### 22. Alcance de esta demo

Esta etapa utiliza la configuración de prueba incluida por Connaisseur y un validador basado en **Notary v1**.

La evidencia demuestra:

```text
Connaisseur instalado
        +
Admission Control
        +
enforcement de confianza
        +
ACCEPT / DENY
```

Todavía no demuestra una firma propia realizada con Cosign.

La siguiente fase será:

```text
Imagen propia
    |
    v
Cosign
    |
    +-- cosign.key
    |
    v
Registry OCI
    |
    v
Connaisseur
    |
    +-- cosign.pub
    |
    +---------+---------+
    |                   |
    v                   v
Firma válida       Firma inválida
    |                   |
    v                   v
 ACCEPT               DENY
```

---

### 23. Entregables cubiertos

| Entregable | Estado |
|---|---|
| Helm chart o manifiestos de instalación | ✅ |
| Connaisseur instalado en Kubernetes | ✅ |
| Configuración de políticas de verificación | ✅ |
| Validación limitada por namespace | ✅ |
| Admission webhook registrado | ✅ |
| Pod aceptado con firma válida | ✅ |
| Pod rechazado sin firma válida | ✅ |
| Evidencias almacenadas | ✅ |
| Integración con clave Cosign propia | Pendiente |

---

### 24. Archivos versionables

Se recomienda subir:

```text
kubernetes/
└── connaisseur/
    └── values.yaml

evidence/
└── connaisseur/
    ├── helm-release.txt
    ├── connaisseur-pods.txt
    ├── connaisseur-webhook.yaml
    ├── namespace-validation.txt
    ├── helm-values.txt
    ├── signed-accepted.txt
    ├── signed-image-reference.txt
    ├── unsigned-rejected.txt
    └── validation-logs.txt
```

No subir llaves privadas, certificados privados, credenciales reales ni manifiestos renderizados con secretos.

---

### 25. Comandos rápidos de validación

```bash
helm list -n connaisseur
```

```bash
kubectl get pods -n connaisseur
```

```bash
kubectl get mutatingwebhookconfigurations
```

```bash
kubectl get namespace supply-chain-demo --show-labels
```

```bash
kubectl get pod signed-demo -n supply-chain-demo
```

```bash
kubectl get pod unsigned-demo -n supply-chain-demo
```

---

### 26. Resultado final de esta fase

```text
Solicitud de despliegue
          |
          v
Kubernetes API Server
          |
          v
Connaisseur
          |
      valida imagen
          |
     +----+----+
     |         |
     v         v
  válida     inválida
     |         |
     v         v
  ACCEPT      DENY
     |         |
     v         X
 Pod creado  Sin Pod
```

La imagen válida quedó además fijada mediante un digest SHA-256, demostrando *trust pinning*.

---

## Fase 4. Integración de Cosign y Connaisseur
En esta fase se integra la llave pública generada por Cosign (`cosign.pub`) dentro de la configuración de Connaisseur para que el clúster valide nuestras propias firmas antes de permitir el despliegue.

### 1. Configurar la llave pública en Connaisseur

Se debe modificar el archivo `kubernetes/connaisseur/values.yaml` para agregar un nuevo validador de tipo `cosign` y establecer la política de confianza para nuestro registro local.

Se edita el archivo `values.yaml` para incluir:

```yaml
application:
  features:
    namespacedValidation:
      mode: validate
  validators:
    - name: validador-cosign-propio
      type: cosign
      trustRoots:
        - name: default-key
          key: |
            -----BEGIN PUBLIC KEY-----
            MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE9ZNEvRihJUcn6mNYZjbUbMW6Myzz
            38mOWRuXyyJmtkXeYGZT34+DMoKfQk2uTXq+rExvLJsS3W3BZ8KTT6598g==
            -----END PUBLIC KEY-----
  policy:
    - pattern: "localhost:5000/*:*"
      validator: validador-cosign-propio
      with:
        trustRoot: default-key
```

### 2. Actualizar la instalación de Connaisseur
Aplicando cambios en el clúster mediante Helm:
```bash
helm upgrade connaisseur /tmp/connaisseur-chart/connaisseur \
  --namespace connaisseur \
  -f /home/adair/proyecto-trivy-cosign/kubernetes/connaisseur/values.yaml
```

Se valida que los pods de Connaisseur se reinicien y tomen la nueva configuración:
```bash
kubectl rollout status deployment/connaisseur -n connaisseur
```


### 3. Despliegue de imágenes
Para demostrar la integración, utilizamos el namespace supply-chain-demo (previamente etiquetado para validación).

Prueba 1: Intento de despliegue de imagen sin firma (DEBE FALLAR)
Utilizaremos una imagen que no ha sido firmada por la llave correcta (nginx>latest se firmo con keys_false).

```bash
kubectl run pod-sin-firma -n supply-chain-demo --image=localhost:5000/nginx:latest
```

Resultado esperado: Connaisseur intercepta la petición y el API Server devuelve un error indicando que no se encontraron firmas válidas (DENY).


Prueba 2: Despliegue de imagen firmada (DEBE FUNCIONAR)
Utilizaremos una de las imágenes que firmamos previamente en la Fase 2.
```bash
kubectl run pod-firmado -n supply-chain-demo --image=localhost:5000/nginx:local
```

Resultado esperado: El pod se crea exitosamente (ACCEPT). PueSe puede verificar con:
```bash
kubectl get pods -n supply-chain-demo
```

## Relación global con ISO/IEC 27001:2022

Este proyecto se ejecuta en la etapa previa al despliegue, actuando como una compuerta de seguridad que decide si un artefacto es apto y comprueba su origen. A continuación se detallan los controles del bloque tecnológico del Anexo A cubiertos:

### A.8.8 — Gestión de vulnerabilidades técnicas
Cubierto principalmente por Trivy mediante:
- reportes de vulnerabilidades;
- clasificación por severidad;
- evaluación de exposición;
- decisiones de tratamiento;
- reescaneo.

### A.8.24 — Uso de criptografía
* **Exigencia de la norma:** Reglas para el uso de criptografía, incluyendo la gestión del ciclo de vida de las llaves.
* **Cobertura en el proyecto:** Implementación de Cosign para la generación del par de llaves, firma criptográfica de las imágenes y verificación mediante Connaisseur.
* **Evidencia:** Procedimiento escrito en este documento sobre la generación y uso de llaves, y capturas de salida de `cosign verify` sobre las 3 imágenes.
* ⚠️ **Brecha residual declarada:** La llave privada (`cosign.key`) se encuentra almacenada en texto plano en el disco local del alumno/operador. Esto no constituye una gestión segura del ciclo de vida (custodia). *Mitigación propuesta:* En un entorno productivo, la llave privada debe migrarse a un sistema KMS (Key Management Service).

### A.8.29 — Pruebas de seguridad en desarrollo y aceptación
Cubierto mediante:
- criterio de aceptación de vulnerabilidades;
- escaneo previo al despliegue;
- admission control con Connaisseur;
- evidencia de una imagen aceptada;
- evidencia de una imagen rechazada.

### A.5.9 — Inventario de información y activos asociados
Cubierto mediante:
- SBOM CycloneDX de las imágenes analizadas.

### A.8.12 — Prevención de fuga de datos
* **Exigencia de la norma:** Aplicar medidas para detectar y evitar la divulgación no autorizada de información.
* **Cobertura en el proyecto:** Escaneo de secretos en el código e imágenes mediante Trivy. Se analizan las distintas capas del contenedor para demostrar que eliminar un secreto en una capa superior (mediante un `rm`) no lo borra del historial de la imagen.
* **Evidencia:** Archivo JSON con el hallazgo del secreto plantado a propósito en la imagen `trivy-secret-demo:v1` y captura de `podman history` mostrando la capa comprometida.

---

## Evidencias del proyecto

### Trivy

```text
reports/json/
reports/html/
reports/sbom/
reports/secrets/
evidence/trivy/
```

### Connaisseur

```text
evidence/connaisseur/
├── helm-release.txt
├── connaisseur-pods.txt
├── connaisseur-webhook.yaml
├── namespace-validation.txt
├── helm-values.txt
├── signed-accepted.txt
├── signed-image-reference.txt
├── unsigned-rejected.txt
└── validation-logs.txt
```

### Cosign

```text
evidence/cosign
├── generate-key-pair.txt
├── sign.txt
├── verify.txt
```

---

## Consideraciones de seguridad del repositorio

Antes de cada `git push`:

```bash
git status
git diff --cached
```

Buscar posibles materiales sensibles:

```bash
git ls-files | grep -Ei '\.(key|pem|p12|pfx)$'
```

Ejemplo de `.gitignore`:

```gitignore
keys/*.key
cosign.key
.env
.env.*
*.pem
*.p12
*.pfx
.trivycache/
.cache/
```

---

## Referencias

### Trivy

- Aqua Security — Trivy Documentation  
  https://trivy.dev/

- Aqua Security — Trivy Installation  
  https://www.trivy.dev/docs/latest/getting-started/installation/

- Aqua Security — Container Image Scanning  
  https://trivy.dev/docs/dev/guide/target/container_image/

### Cosign

- Cosign GitHub Repository
  https://github.com/sigstore/cosign

- Sigstore Cosign Documentation
  https://docs.sigstore.dev/cosign/signing/overview/


### Connaisseur

- Connaisseur Documentation  
  https://sse-secure-systems.github.io/connaisseur/latest/

- Connaisseur GitHub Repository  
  https://github.com/sse-secure-systems/connaisseur

### Kubernetes y Helm

- Helm Documentation  
  https://helm.sh/docs/

- Kubernetes Admission Control  
  https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/

---

## Estado final actual

```text
Trivy                          ✅ COMPLETADO
Connaisseur base               ✅ COMPLETADO
Cosign                         ✅ COMPLETADO
Integración Cosign-Connaisseur ⏳ PENDIENTE
```
