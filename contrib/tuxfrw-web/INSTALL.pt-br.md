# Guia de Instalação e Configuração do TuxFrw-Web

Este documento descreve o procedimento completo para compilar, instalar, configurar e colocar em produção o daemon de gerenciamento web **`tuxfrw-web`** em servidores GNU/Linux que já possuem o **TuxFrw-NFT** instalado e em operação.

*(English version available in [INSTALL.md](INSTALL.md))*

---

## 1. Visão Geral e Arquitetura

O **TuxFrw-Web** é um serviço leve e seguro desenvolvido em **Rust** que atua como dashboard e interface gráfica para administração do `TuxFrw-NFT`. Ele provê:

- **HTTPS Nativo (TLS)**: Tráfego cifrado ponta a ponta sem necessidade obrigatória de proxy reverso.
- **Dual-Stack Nativo (IPv6 + IPv4)**: O socket escuta em `[::]:8443`, atendendo requisições IPv4 e IPv6 simultaneamente.
- **Autenticação Segura via Argon2id**: Senha cifrada e armazenada no arquivo central `/etc/tuxfrw-nft/config.toml`.
- **Validação de Sintaxe Pré-Salvamento (2 Níveis)**: Teste de sintaxe Bash (`bash -n`) e dry-run no compilador do kernel nftables (`nft -c`) antes de qualquer alteração ir para o disco, protegendo o firewall contra erros de digitação.
- **Zero Dependências em Produção**: O executável compilado é um binário estático único contendo todo o backend e os templates HTML pré-compilados.
- **Operação Não-Destrutiva**: Interage com o firewall através do executável `/usr/sbin/tuxfrw-nft` e consulta o estado via `nft -j list ruleset`.

---

## 2. Pré-Requisitos

1. **Servidor com TuxFrw-NFT em Operação**:
   - Binário `/usr/sbin/tuxfrw-nft` presente e executável (`0700`).
   - Diretório de configurações `/etc/tuxfrw-nft/` existente e configurado.
   - Pacote `nftables` instalado e ativo no kernel.
2. **Ambiente de Compilação (Build)**:
   - Se for compilar no próprio servidor ou em máquina de build:
     - Rust e Cargo instalados (versão 1.75 ou superior recomendada):
       ```bash
       curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
       source "$HOME/.cargo/env"
       ```
     - Ferramentas essenciais de compilação:
       ```bash
       # Debian / Ubuntu:
       sudo apt update && sudo apt install -y build-essential pkg-config libssl-dev

       # RHEL / Rocky Linux / AlmaLinux:
       sudo dnf groupinstall -y "Development Tools" && sudo dnf install -y openssl-devel
       ```

---

## 3. Passo a Passo de Compilação

Execute a compilação otimizada para produção:

```bash
cd contrib/tuxfrw-web
cargo build --release
```

O binário final será gerado em:
`target/release/tuxfrw-web`

---

## 4. Instalação no Sistema Operacional

Com privilégios de superusuário (`root`), copie o binário e prepare a estrutura de arquivos em `/etc/tuxfrw-nft`:

```bash
# 1. Instalar o executável no PATH do sistema
sudo cp target/release/tuxfrw-web /usr/local/bin/tuxfrw-web
sudo chown root:root /usr/local/bin/tuxfrw-web
sudo chmod 0700 /usr/local/bin/tuxfrw-web

# 2. Criar diretório para certificados TLS
sudo mkdir -p /etc/tuxfrw-nft/tls
sudo chmod 0700 /etc/tuxfrw-nft/tls

# 3. Copiar o arquivo de configuração para /etc/tuxfrw-nft/config.toml
# (Caso já não exista)
if [ ! -f /etc/tuxfrw-nft/config.toml ]; then
    sudo cp config.example.toml /etc/tuxfrw-nft/config.toml
    sudo chown root:root /etc/tuxfrw-nft/config.toml
    sudo chmod 0600 /etc/tuxfrw-nft/config.toml
fi
```

### Resumo das Permissões Aplicadas

| Caminho | Permissão | Dono | Finalidade |
| :--- | :--- | :--- | :--- |
| `/usr/local/bin/tuxfrw-web` | `0700` (`rwx------`) | `root:root` | Binário executável do daemon |
| `/etc/tuxfrw-nft/config.toml` | `0600` (`rw-------`) | `root:root` | Configurações do servidor e credenciais |
| `/etc/tuxfrw-nft/tls/` | `0700` (`rwx------`) | `root:root` | Certificados TLS e chaves privadas |

---

## 5. Configuração Detalhada (`/etc/tuxfrw-nft/config.toml`)

Edite o arquivo de configuração:
```bash
sudo nano /etc/tuxfrw-nft/config.toml
```

Exemplo de configuração recomendada para produção:

```toml
[server]
# Escuta em Dual-Stack em todas as interfaces IPv6 e IPv4 na porta 8443:
listen = "[::]:8443"

# Prefixo de rota (deixe "/" para raiz)
base_path = "/"

# Habilitar HTTPS
tls_enabled = true

# Caminhos dos certificados TLS
cert_path = "/etc/tuxfrw-nft/tls/cert.pem"
key_path = "/etc/tuxfrw-nft/tls/key.pem"

# Se true, gera automaticamente um certificado auto-assinado caso os arquivos acima não existam
auto_generate_self_signed = true

[auth]
# Usuário administrador do painel
username = "admin"

# Hash da senha em formato Argon2id
# Senha padrão inicial: "admin"
password_hash = "$argon2id$v=19$m=19456,t=2,p=1$c29tZXNhbHQ$59f1rFvjDsmE8Fj2kU+sV3R6/pL2y3rB8Q2wVb1zKxY"

# Tempo de validade da sessão em minutos
session_timeout_minutes = 60

# Chave secreta de sessão (deixe vazio para gerar aleatoriamente a cada boot)
secret_key = ""

[firewall]
# Executável do TuxFrw
tuxfrw_bin = "/usr/sbin/tuxfrw-nft"

# Diretório base do firewall
config_dir = "/etc/tuxfrw-nft"

# Utilitário nftables
nft_bin = "/usr/sbin/nft"

# Timeout em segundos para execução de comandos do firewall
command_timeout_seconds = 15
```

> [!TIP]
> **Como Gerar um Novo Hash de Senha Argon2id**:
> Você pode gerar o hash de qualquer nova senha diretamente pelo próprio binário:
> ```bash
> tuxfrw-web --hash-password "sua_nova_senha_secreta"
> ```
> O comando exibirá o hash criptográfico pronto para colar na diretiva `password_hash` do seu `/etc/tuxfrw-nft/config.toml`.

---

## 6. Certificados TLS (HTTPS)

O `tuxfrw-web` oferece duas modalidades de HTTPS:

### Opção A: Certificado Auto-Assinado Automático (Padrão)
Se `auto_generate_self_signed = true` e os arquivos de certificado não forem encontrados em `/etc/tuxfrw-nft/tls/`, o daemon **gerará automaticamente** um certificado ECDSA auto-assinado na primeira inicialização.
- O navegador exibirá um alerta de segurança normal para certificados auto-assinados ("Conexão não é privada"). Basta aceitar e prosseguir.

### Opção B: Certificado Válido (Let's Encrypt / Certbot / Autoridade Pública)
Caso possua um certificado emitido para o domínio do servidor (ex: `firewall.empresa.com.br`):

```bash
# Exemplo com Certbot:
sudo cp /etc/letsencrypt/live/firewall.empresa.com.br/fullchain.pem /etc/tuxfrw-nft/tls/cert.pem
sudo cp /etc/letsencrypt/live/firewall.empresa.com.br/privkey.pem /etc/tuxfrw-nft/tls/key.pem

# Assegurar permissões estritas
sudo chown root:root /etc/tuxfrw-nft/tls/*
sudo chmod 0600 /etc/tuxfrw-nft/tls/key.pem
sudo chmod 0644 /etc/tuxfrw-nft/tls/cert.pem
```

---

## 7. Liberação da Porta no Próprio Firewall (`TuxFrw-NFT`)

> [!IMPORTANT]
> Como o TuxFrw-NFT opera com política restritiva de entrada (`INPUT drop`), a porta TCP `8443` **deve ser liberada** para os IPs de administração autorizados no módulo [`rules/tf_INPUT.mod`](/etc/tuxfrw-nft/rules/tf_INPUT.mod), caso contrário o tráfego será descartado antes de atingir o socket web.

Edite o módulo `/etc/tuxfrw-nft/rules/tf_INPUT.mod`:

### Exemplo 1: Liberar a porta 8443 apenas para a rede interna (Intranet / LAN)
```bash
if [ "$INT_IFACE" != "" ]; then
    $NFT "add rule inet filter INPUT iifname $INT_IFACE tcp dport 8443 counter accept"
fi
```

### Exemplo 2: Liberar a porta 8443 apenas para os IPs de administração remota
```bash
if [ "$RMT_ADMIN_IP" != "" ]; then
    $NFT "add rule inet filter INPUT ip saddr $RMT_ADMIN_IP tcp dport 8443 counter accept"
fi
if [ "$RMT_ADMIN_IP6" != "" ]; then
    $NFT "add rule inet filter INPUT ip6 saddr $RMT_ADMIN_IP6 tcp dport 8443 counter accept"
fi
```

### Exemplo 3: Liberar acesso à porta 8443 através da VPN
No arquivo `/etc/tuxfrw-nft/rules/tf_INPUT.mod`, adicione:
```bash
# Permite acesso à interface web a partir de qualquer interface de VPN ativa:
if [ "$OpenVPN_IFACE" != "" ]; then
    $NFT "add rule inet filter INPUT iifname $OpenVPN_IFACE tcp dport 8443 counter accept"
fi
if [ "$WG_IFACE" != "" ]; then
    $NFT "add rule inet filter INPUT iifname $WG_IFACE tcp dport 8443 counter accept"
fi
```

Após editar `tf_INPUT.mod`, recarregue as regras de entrada:
```bash
sudo tuxfrw-nft load INPUT
```

---

## 8. Inicialização Automática com Systemd (`tuxfrw-web.service`)

O projeto já inclui um arquivo de unidade systemd pronto e otimizado em [`tuxfrw-web.service`](tuxfrw-web.service).

### 8.1. Instalação da Unidade de Serviço

Você pode copiar diretamente o arquivo fornecido pelo projeto ou criá-lo manualmente:

```bash
# Opção A: Copiar o arquivo pronto do projeto
sudo cp tuxfrw-web.service /etc/systemd/system/tuxfrw-web.service
sudo chmod 0644 /etc/systemd/system/tuxfrw-web.service

# Opção B: Criar/editar manualmente com nano
sudo nano /etc/systemd/system/tuxfrw-web.service
```

### 8.2. Conteúdo da Unidade (`/etc/systemd/system/tuxfrw-web.service`)

```ini
[Unit]
Description=TuxFrw-NFT Web Management Daemon (HTTPS Dual-Stack)
Documentation=https://github.com/gondimcodes/tuxfrw-nft
After=network-online.target tuxfrw-nft.service
Wants=network-online.target tuxfrw-nft.service

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/tuxfrw-web
Restart=on-failure
RestartSec=5s

# Hardening e limites operacionais
LimitNOFILE=65535
TimeoutStopSec=10s
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

### 8.3. Detalhamento Técnico das Diretivas

- **`After=network-online.target tuxfrw-nft.service`**: Assegura que o socket web só seja aberto após o firewall e a rede estarem 100% inicializados e filtrados no kernel.
- **`Wants=network-online.target tuxfrw-nft.service`**: Estabelece a dependência de inicialização conjunta com o firewall base.
- **`Restart=on-failure` & `RestartSec=5s`**: Resiliência e alta disponibilidade: se o processo for encerrado por um sinal não previsto, o systemd o reinicia automaticamente após 5 segundos.
- **`LimitNOFILE=65535`**: Aumenta o limite de descritores de arquivo, suportando tráfego volumoso e sessões simultâneas sem erro de `Too many open files`.
- **`PrivateTmp=true`**: Isola o `/tmp` do processo em um namespace privado do kernel, impedindo qualquer acesso ou interferência em arquivos temporários de outros serviços.

### 8.4. Comandos de Gerenciamento do Serviço

Após instalar ou modificar o arquivo de unidade:

```bash
# 1. Recarregar o systemd para reconhecer a nova unidade
sudo systemctl daemon-reload

# 2. Habilitar na inicialização do sistema e iniciar imediatamente (--now)
sudo systemctl enable --now tuxfrw-web

# 3. Verificar o status e verificar se o daemon está ativo (active / running)
sudo systemctl status tuxfrw-web

# 4. Comandos úteis de operação do dia a dia
sudo systemctl restart tuxfrw-web   # Reinicia o daemon web
sudo systemctl stop tuxfrw-web      # Interrompe o daemon web
sudo systemctl disable tuxfrw-web   # Remove da inicialização automática

# 5. Monitorar logs de execução em tempo real
sudo journalctl -u tuxfrw-web -f
```

---

## 9. Validação e Primeiro Acesso

1. **Acesse no navegador**:
   ```text
   https://<IP_DO_SERVIDOR_OU_DOMINIO>:8443
   ```
   *(Caso utilize IPv6 puro no navegador: `https://[2001:db8::1]:8443`)*

2. **Efetue o Login**:
   - **Usuário**: `admin`
   - **Senha**: `admin`

3. **Verificação dos Recursos no Painel**:
   - Na tela principal (**Dashboard**), você visualizará o status das regras ativas do Netfilter e os botões de ação rápida (`Iniciar`, `Reiniciar`, `Parar`, `Atualizar Cloudflare`, `Modo Pânico` e `Recarga Atômica`).
   - Navegue até a aba **tuxfrw.conf** para visualizar o editor central do arquivo de configuração.
   - Navegue até a aba **Módulos Rules** para inspecionar, testar (`🧪 Testar Sintaxe`) e editar qualquer um dos módulos de regras com validação estrita pré-salvamento.

---

## 10. Diagnóstico e Resolução de Problemas (Troubleshooting)

### Verificar logs de execução em tempo real
```bash
sudo journalctl -u tuxfrw-web -f
```

### Testar resposta do daemon via terminal (IPv4 e IPv6)
```bash
# Teste local IPv4
curl -k -I https://127.0.0.1:8443/health

# Teste local IPv6
curl -k -I https://[::1]:8443/health
```
Ambos devem responder com HTTP 200:
`HTTP/2 200` ou `HTTP/1.1 200 OK`

### Problema: Porta 8443 já em uso
Se a porta 8443 estiver ocupada por outro serviço (ex: Tomcat, Unifi, etc.):
1. Altere `listen = "[::]:9443"` em `/etc/tuxfrw-nft/config.toml`.
2. Atualize a regra de liberação no `tf_INPUT.mod` para a nova porta.
3. Reinicie o serviço: `sudo systemctl restart tuxfrw-web`.

### Problema: Navegador não conecta (Timeout / Conexão Recusada)
1. Confirme se o serviço está rodando: `sudo systemctl status tuxfrw-web`.
2. Verifique se o daemon está ouvindo na porta: `sudo ss -tulpn | grep 8443`.
3. Verifique se as regras do TuxFrw-NFT estão bloqueando a porta: `sudo journalctl -k -f | grep "tuxfrw:"`.
4. Garanta que adicionou a regra de liberação da porta `8443` em `rules/tf_INPUT.mod` conforme a Seção 7 deste guia.

