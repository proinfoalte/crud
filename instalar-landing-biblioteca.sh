#!/bin/bash
# Instalador: landing publica en la raiz "/" de biblioteca.psicodominicana.site
# - Respalda nginx y la portada actual
# - Agrega SOLO "location = /" (coincidencia exacta): los modulos y /acceso/ no se tocan
# - Corre "nginx -t" antes de recargar; si algo falla, deshace todo solo
# - Prueba que "/" abre la landing y que los modulos sin sesion siguen mandando a /acceso/
set -u

DOM="biblioteca.psicodominicana.site"
LANDING="/root/landing-biblioteca-psicodominicana.html"
DEST="/var/www/landing-biblioteca"
FECHA=$(date +%Y%m%d-%H%M%S)
BK="/root/respaldo-biblioteca-$FECHA"
MARCA="# LANDING-BIBLIOTECA (instalador)"

ok()    { echo "✅ $*"; }
aviso() { echo "⚠️  $*"; }
fallo() { echo "❌ $*"; exit 1; }

pedir() { # pedir RUTA -> "codigo redireccion"
  local r
  r=$(curl -sk -o /dev/null -w "%{http_code} %{redirect_url}" --max-time 15 \
      --noproxy "*" --resolve "$DOM:443:127.0.0.1" "https://$DOM$1")
  [ "${r%% *}" = "000" ] && r=$(curl -sk -o /dev/null -w "%{http_code} %{redirect_url}" --max-time 15 "https://$DOM$1")
  echo "$r"
}
cuerpo() {
  curl -sk --max-time 15 --noproxy "*" --resolve "$DOM:443:127.0.0.1" "https://$DOM/" 2>/dev/null \
    || curl -sk --max-time 15 "https://$DOM/"
}

echo "===== 1. Verificaciones previas ====="
[ "$(id -u)" = 0 ] || fallo "Corre esto como root (sudo -i)."
[ -s "$LANDING" ] || fallo "No existe o esta vacio: $LANDING"
nginx -t >/dev/null 2>&1 || fallo "nginx -t ya falla ANTES de tocar nada. No sigo."
command -v curl >/dev/null || fallo "Falta curl (apt install curl)."

mapfile -t CONFS < <(nginx -T 2>/dev/null | awk -v d="$DOM" '
  /^# configuration file /{f=$4; sub(/:$/,"",f); next}
  /server_name/ && index($0,d) {print f}' | sort -u | xargs -r -n1 readlink -f | sort -u)
[ ${#CONFS[@]} -gt 0 ] || fallo "No encontre 'server_name $DOM' en la config de nginx."
grep -qF "$MARCA" "${CONFS[@]}" && fallo "La landing ya estaba instalada (encontre la marca). No hago nada."
ok "Config del dominio: ${CONFS[*]}"

ROOT=$(grep -hoP '^\s*root\s+\K[^;]+' "${CONFS[@]}" | head -1)
[ -n "$ROOT" ] && ok "Raiz actual del sitio: $ROOT" || aviso "No encontre 'root' en la config."

echo; echo "===== 2. Estado ANTES del cambio ====="
ACCESO_ANTES=$(pedir /acceso/)
echo "/acceso/ -> $ACCESO_ANTES"
MODULOS=()
if [ -n "$ROOT" ] && [ -d "$ROOT" ]; then
  for d in "$ROOT"/*/; do
    m=$(basename "$d")
    case "$m" in acceso|assets|css|js|img|images|imagenes|fonts|vendor|uploads|static|.well-known) continue;; esac
    r=$(pedir "/$m/")
    echo "/$m/ -> $r"
    case "$r" in 30[1278]\ *acceso*) MODULOS+=("$m");; esac
  done
fi
[ ${#MODULOS[@]} -gt 0 ] && ok "Modulos que hoy redirigen a /acceso/: ${MODULOS[*]}" \
  || aviso "No encontre modulos que redirijan a /acceso/ por carpeta; esa prueba sera solo informativa."

echo; echo "===== 3. Copias de seguridad en $BK ====="
mkdir -p "$BK/confs" "$BK/portada" || fallo "No pude crear $BK"
tar czf "$BK/nginx-completo.tar.gz" -C / etc/nginx || fallo "No pude respaldar /etc/nginx"
for c in "${CONFS[@]}"; do cp -a --parents "$c" "$BK/confs/"; done
[ -n "$ROOT" ] && cp -a "$ROOT"/index.* "$BK/portada/" 2>/dev/null
cat > "$BK/deshacer.sh" <<EOF
#!/bin/bash
# Deja nginx exactamente como estaba antes del instalador
cp -a "$BK/confs/." /
nginx -t && (systemctl reload nginx || nginx -s reload) && echo "Restaurado."
EOF
chmod +x "$BK/deshacer.sh"
ok "Respaldo de nginx, de la portada actual y script para deshacer: $BK/deshacer.sh"

restaurar() {
  cp -a "$BK/confs/." /
  nginx -t >/dev/null 2>&1 && (systemctl reload nginx 2>/dev/null || nginx -s reload)
  echo "↩️  Restaure la config original de nginx."
}

echo; echo "===== 4. Instalando la landing ====="
mkdir -p "$DEST"
cp "$LANDING" "$DEST/index.html"
chmod 755 "$DEST"; chmod 644 "$DEST/index.html"
ok "Landing copiada a $DEST/index.html (la portada actual en $ROOT no se toca)"

EXTRA=""
grep -qE '^\s*auth_basic\s' "${CONFS[@]}"   && EXTRA+="        auth_basic off;\n"
grep -qE '^\s*auth_request\s' "${CONFS[@]}" && EXTRA+="        auth_request off;\n"
BLOQUE="\n    $MARCA - portada publica sin login\n    location = / {\n${EXTRA}        root $DEST;\n        try_files /index.html =404;\n    }\n"

TOTAL=0
for c in "${CONFS[@]}"; do
  tmp=$(mktemp)
  res=$(awk -v d="$DOM" -v blk="$BLOQUE" '
    NR==FNR {
      l=$0; sub(/#.*/,"",l)
      if (!insrv && l ~ /^[ \t]*server[ \t]*\{/) { insrv=1; sd=depth; dom=0; ssl=0; ex=0; snl=0; sn=0 }
      if (insrv) {
        if (l ~ /^[ \t]*server_name[ \t]/) sn=1
        if (sn && index(l,d)) dom=1
        if (sn && l ~ /;/) { if (dom && !snl) snl=FNR; sn=0 }
        if (l ~ /^[ \t]*listen[ \t].*(443|ssl)/) ssl=1
        if (l ~ /location[ \t]*=[ \t]*\/[ \t]*(\{|$)/) ex=1
      }
      o=gsub(/\{/,"{",l); c=gsub(/\}/,"}",l); depth+=o-c
      if (insrv && depth<=sd) { insrv=0; if (dom && ssl) { if (ex) conf++; else if (snl) ins[snl]=1 } }
      next
    }
    { print } (FNR in ins) { printf "%s", blk; n++ }
    END { print (n+0) " " (conf+0) > "/dev/stderr" }' "$c" "$c" 2>&1 >"$tmp")
  set -- $res
  if [ "${2:-0}" -gt 0 ]; then rm -f "$tmp"; restaurar; fallo "$c ya tiene un 'location = /' propio. No lo piso; revisalo a mano."; fi
  if [ "${1:-0}" -gt 0 ]; then cat "$tmp" > "$c"; TOTAL=$((TOTAL+$1)); ok "Agregue 'location = /' en $c ($1 bloque/s HTTPS)"; fi
  rm -f "$tmp"
done
[ "$TOTAL" -gt 0 ] || { restaurar; fallo "No encontre un bloque HTTPS (listen 443/ssl) de $DOM donde insertar."; }

echo; echo "===== 5. nginx -t y recarga ====="
if ! nginx -t; then restaurar; fallo "nginx -t fallo con el cambio. Todo quedo como estaba."; fi
systemctl reload nginx 2>/dev/null || nginx -s reload || { restaurar; fallo "No pude recargar nginx."; }
sleep 2
ok "nginx recargado"

echo; echo "===== 6. Pruebas ====="
R=$(pedir /); echo "/ -> $R"
if [ "${R%% *}" != "200" ] || [ "$(cuerpo | md5sum)" != "$(md5sum < "$DEST/index.html")" ]; then
  restaurar; fallo "'/' no devuelve la landing. Deshice el cambio."
fi
ok "'/' abre la landing (200, contenido identico al archivo)"

MAL=0
for m in "${MODULOS[@]}"; do
  r=$(pedir "/$m/"); echo "/$m/ -> $r"
  case "$r" in 30[1278]\ *acceso*) ;; *) MAL=1;; esac
done
ACCESO_DESPUES=$(pedir /acceso/); echo "/acceso/ -> $ACCESO_DESPUES"
[ "${ACCESO_DESPUES%% *}" = "${ACCESO_ANTES%% *}" ] || MAL=1
if [ "$MAL" = 1 ]; then restaurar; fallo "Un modulo o /acceso/ cambio de comportamiento. Deshice el cambio."; fi
[ ${#MODULOS[@]} -gt 0 ] && ok "Modulos sin sesion siguen mandando a /acceso/; /acceso/ igual que antes"

echo; echo "Prueba publica (por si hay CDN delante): / -> $(curl -sk -o /dev/null -w '%{http_code}' --max-time 15 https://$DOM/)"

echo; echo "===== QUE CAMBIE ====="
echo "1. Nuevo: $DEST/index.html (copia de $LANDING)."
echo "2. En ${CONFS[*]}: agregue un bloque 'location = /' (marcado con '$MARCA')"
echo "   que sirve la landing sin login SOLO en la raiz exacta '/'."
echo "3. No toque la portada vieja, los modulos ni /acceso/."
echo "4. Respaldos: $BK  (nginx completo, confs, portada anterior)"
echo "5. Para deshacer: bash $BK/deshacer.sh"
