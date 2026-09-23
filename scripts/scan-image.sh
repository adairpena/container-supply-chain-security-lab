#!/usr/bin/env bash

set -Eeuo pipefail

IMAGE="${1:-}"

if [[ -z "$IMAGE" ]]; then
    echo "Uso:"
    echo "  $0 <imagen>"
    echo
    echo "Ejemplo:"
    echo "  $0 nginx:latest"
    exit 1
fi

SAFE_NAME=$(echo "$IMAGE" | tr '/:@' '____')

PODMAN_SOCKET="/run/podman/podman.sock"

JSON_DIR="reports/json"
HTML_DIR="reports/html"
SBOM_DIR="reports/sbom"
SECRET_DIR="reports/secrets"

mkdir -p \
    "$JSON_DIR" \
    "$HTML_DIR" \
    "$SBOM_DIR" \
    "$SECRET_DIR"

echo "=================================================="
echo "          TRIVY - ESCANEO MANUAL"
echo "=================================================="
echo "Imagen : $IMAGE"
echo "Fecha  : $(date --iso-8601=seconds)"
echo "Host   : $(hostname)"
echo "=================================================="

if [[ ! -S "$PODMAN_SOCKET" ]]; then
    echo
    echo "ERROR: Podman socket no disponible:"
    echo "  $PODMAN_SOCKET"
    echo
    echo "Ejecuta:"
    echo "  systemctl enable --now podman.socket"
    exit 1
fi

echo
echo "[1/4] Escaneo de vulnerabilidades -> JSON"

trivy image \
    --podman-host "$PODMAN_SOCKET" \
    --image-src podman \
    --scanners vuln \
    --format json \
    --output "${JSON_DIR}/${SAFE_NAME}.json" \
    "$IMAGE"

echo
echo "[2/4] Escaneo de vulnerabilidades -> HTML"

trivy image \
    --podman-host "$PODMAN_SOCKET" \
    --image-src podman \
    --scanners vuln \
    --format template \
    --template "@/usr/local/share/trivy/templates/html.tpl" \
    --output "${HTML_DIR}/${SAFE_NAME}.html" \
    "$IMAGE"

echo
echo "[3/4] SBOM -> CycloneDX"

trivy image \
    --podman-host "$PODMAN_SOCKET" \
    --image-src podman \
    --format cyclonedx \
    --output "${SBOM_DIR}/${SAFE_NAME}.cdx.json" \
    "$IMAGE"

echo
echo "[4/4] Secret scanning -> JSON"

trivy image \
    --podman-host "$PODMAN_SOCKET" \
    --image-src podman \
    --scanners secret \
    --format json \
    --output "${SECRET_DIR}/${SAFE_NAME}-secrets.json" \
    "$IMAGE"

echo
echo "=================================================="
echo "              ESCANEO TERMINADO"
echo "=================================================="
echo
echo "Vulnerabilidades:"
echo "  ${JSON_DIR}/${SAFE_NAME}.json"
echo
echo "HTML:"
echo "  ${HTML_DIR}/${SAFE_NAME}.html"
echo
echo "SBOM:"
echo "  ${SBOM_DIR}/${SAFE_NAME}.cdx.json"
echo
echo "Secretos:"
echo "  ${SECRET_DIR}/${SAFE_NAME}-secrets.json"
