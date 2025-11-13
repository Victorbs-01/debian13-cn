#!/usr/bin/env bash
# docker-diagnose.sh — Diagnóstico rápido de Docker en Debian

set -u
GREEN='\033[1;32m'; RED='\033[1;31m'; YEL='\033[1;33m'; NC='\033[0m'
ok(){ echo -e "${GREEN}✔ $*${NC}"; }
warn(){ echo -e "${YEL}⚠ $*${NC}"; }
fail(){ echo -e "${RED}✘ $*${NC}"; }

section(){ echo -e "\n${YEL}==> $*${NC}"; }

PASS=0; FAIL=0
t(){ if "$@"; then ok "$*"; ((PASS++)); else fail "$*"; ((FAIL++)); fi; }

section "1) Binarios y servicio"
t command -v docker >/dev/null
systemctl is-active --quiet docker && ok "docker.service activo" || { fail "docker.service INACTIVO"; systemctl status docker --no-pager; ((FAIL++)); }

section "2) Grupos y socket"
USER_NAME=${SUDO_USER:-$USER}
id "$USER_NAME"
groups "$USER_NAME" | grep -qw docker && ok "Usuario '$USER_NAME' está en el grupo docker" || warn "Usuario '$USER_NAME' NO está en el grupo docker"
[ -S /var/run/docker.sock ] && ok "Socket /var/run/docker.sock existe" || fail "No existe /var/run/docker.sock"
ls -l /var/run/docker.sock || true

section "3) Kernel / forwarding / módulos"
SYS_FWD=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo 0)
[ "$SYS_FWD" -eq 1 ] && ok "net.ipv4.ip_forward=1" || fail "net.ipv4.ip_forward=$SYS_FWD"
lsmod | grep -q br_netfilter && ok "módulo br_netfilter cargado" || warn "br_netfilter no cargado (suele ser ok)"
command -v nft >/dev/null && nft list ruleset | grep -q 'chain forward' && ok "nftables presente" || warn "nftables no tiene chain forward visible (puede ser normal)"

section "4) Bridge docker0"
ip addr show docker0 >/dev/null 2>&1 && ok "Interfaz docker0 presente" || fail "docker0 no existe"
GW=$(docker network inspect bridge -f '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || echo "")
[ -n "$GW" ] && ok "Gateway del bridge: $GW" || warn "No se obtuvo gateway del bridge"

section "5) Info Docker"
docker version && ((PASS++)) || ((FAIL++))
docker info | sed -n '1,25p' || true

section "6) Test contenedor (sin red externa)"
t docker run --rm --network bridge alpine:3.20 sh -c "echo OK"
t docker run --rm --network bridge alpine:3.20 sh -c "ip route; ping -c1 -W2 ${GW:-172.17.0.1}"

section "7) Test red externa (con mirrors si los tienes)"
# DNS público China (Ali 223.5.5.5 / 223.6.6.6). Usamos ping e nslookup de busybox.
t docker run --rm alpine:3.20 sh -c "ping -c1 -W3 223.5.5.5"
docker run --rm alpine:3.20 sh -c "nslookup docker.io 223.5.5.5 || nslookup google.com 223.5.5.5" && ok "DNS dentro del contenedor OK" || warn "Falla DNS dentro del contenedor"

section "8) Pull rápido"
docker pull --quiet alpine:3.20 && ok "Pull de alpine OK" || warn "Pull de alpine con problemas (posible bloqueo/latencia)"

section "RESUMEN"
echo -e "${GREEN}PASADAS: $PASS${NC} | ${RED}FALLIDAS: $FAIL${NC}"
[ "$FAIL" -eq 0 ] && echo -e "${GREEN}Diagnóstico: TODO OK para usar Docker.${NC}" || echo -e "${RED}Diagnóstico: revisa los puntos marcados como ✘ arriba.${NC}"
