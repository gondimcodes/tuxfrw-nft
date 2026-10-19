# TuxFrw-Web

> **Daemon e Interface Web de Gerenciamento para o Firewall TuxFrw-NFT**  
> *Construído em Rust com Axum, Tokio, HTTPS nativo (TLS), Dual-Stack IPv6/IPv4 e CAPTCHA Criptográfico.*

---

## Recursos Principais

- **Segurança de Memória e Alta Performance**: Desenvolvido 100% em **Rust**, compilando para um único binário executável estático sem dependências de interpretadores (Node.js, Python ou PHP) no servidor de produção.
- **HTTPS Nativo (TLS)**: Suporte integrado via `rustls` com carregamento de certificados PEM ou geração automática de certificado auto-assinado ECDSA no primeiro boot.
- **Dual-Stack Nativo (IPv6 + IPv4)**: O daemon escuta em `[::]:9443` (ou porta configurável), aceitando conexões simultâneas de clientes IPv6 e IPv4.
- **Autenticação Segura via Argon2id & API REST**: Senhas armazenadas com algoritmo criptográfico Argon2id em `/etc/tuxfrw-nft/config.toml`, com sessões isoladas em cookies `HttpOnly; Secure; SameSite=Lax`.
- **CAPTCHA Criptográfico SVG**: Desafio visual dinâmico com caracteres não-ambíguos, linhas de ruído ótico, efeito glow neon e assinatura stateless HMAC-SHA256 (validade de 5 minutos, anti-replay e anti-força-bruta).
- **Suporte Multilíngue (i18n)**: Seletor de idiomas dinâmico com suporte nativo a **Português (Brasil)** e **English** em todas as telas e mensagens do painel.
- **Painel de Operações Rápidas**:
  - `start`, `stop` (não-destrutivo), `restart`, `cf-update` (Cloudflare CDN);
  - **Modo Pânico (Lockdown Emergencial)** com diálogo de confirmação.
- **Recarga Atômica Dinâmica de Módulos**:
  - Seletor rápido para os 22 módulos de regras (`INPUT`, `SYNPROXY`, `DOCKER`, `FORWARD`, `URPF`, `NETDEV`, etc.), disparando `tuxfrw-nft load <MODULE>` com retorno imediato do log no console da web.
- **Editor Web Integrado com Pré-Validação de Sintaxe (2 Níveis)**:
  - Edição direta de `/etc/tuxfrw-nft/tuxfrw.conf` e de todos os módulos em `/etc/tuxfrw-nft/rules/*.mod`.
  - Validação estrita automática com `bash -n` e `nft -c` (dry-run do kernel), bloqueando gravações caso haja erros de sintaxe e preservando a integridade dos arquivos originais.
- **Console de Execução em Tempo Real**: Visualização ao vivo com interpretação de cores ANSI e alinhamento no navegador.

> Para o manual completo de instalação e configuração, consulte [**INSTALL.md (English)**](INSTALL.md) ou [**INSTALL.pt-br.md (Português)**](INSTALL.pt-br.md).

---

## Estrutura do Projeto

```text
contrib/tuxfrw-web/
├── Cargo.toml               # Dependências Rust (Axum, Tokio, Rustls, Argon2, HMAC, Askama)
├── config.example.toml      # Modelo de configuração para /etc/tuxfrw-nft/config.toml
├── README.md                # Documentação técnica em inglês
├── README.pt-br.md          # Documentação técnica em português
├── INSTALL.md               # Manual de instalação em inglês
├── INSTALL.pt-br.md         # Manual de instalação em português
├── tuxfrw-web.service       # Unidade de serviço systemd
├── src/
│   ├── main.rs              # Inicializador do daemon, bindings HTTPS e Dual-Stack
│   ├── config.rs            # Loader e escritor atômico do config.toml
│   ├── tls.rs               # Gestão e auto-geração de certificados TLS
│   ├── auth/                # Hashing Argon2id, sessões e CaptchaEngine
│   │   ├── mod.rs
│   │   ├── captcha.rs
│   │   ├── password.rs
│   │   └── session.rs
│   ├── firewall/            # Execução de comandos do tuxfrw-nft e validação de sintaxe
│   │   ├── mod.rs
│   │   ├── command.rs
│   │   └── config_parser.rs
│   └── routes/              # Handlers HTTP, API REST e middleware de autenticação
│       ├── mod.rs
│       ├── auth.rs
│       ├── dashboard.rs
│       ├── config_view.rs
│       ├── rules_view.rs
│       └── api.rs
└── templates/               # Templates HTML pré-compilados no binário (Askama)
    ├── base.html
    ├── login.html
    ├── dashboard.html
    ├── config.html
    └── rules.html
```

---

## Compilação e Instalação

### 1. Compilação do Binário
No servidor de compilação ou homologação:
```bash
cd contrib/tuxfrw-web
cargo build --release
```
O binário otimizado será gerado em `target/release/tuxfrw-web`.

### 2. Instalação no Sistema Operacional
```bash
# Copiar o binário executável para o diretório de binários do sistema
sudo cp target/release/tuxfrw-web /usr/local/bin/tuxfrw-web
sudo chmod 0700 /usr/local/bin/tuxfrw-web

# Copiar o arquivo de configuração de exemplo para /etc/tuxfrw-nft/config.toml
sudo cp config.example.toml /etc/tuxfrw-nft/config.toml
sudo chmod 0600 /etc/tuxfrw-nft/config.toml
```

### 3. Configuração do Serviço Systemd (`tuxfrw-web.service`)
Copie ou crie a unidade `/etc/systemd/system/tuxfrw-web.service`:

```bash
sudo cp tuxfrw-web.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tuxfrw-web
```

---

## Acesso Inicial

Acesse no navegador:
`https://<IP_DO_SERVIDOR>:8443` (ou porta configurada, ex: `9443`)

- **Usuário padrão**: `admin`
- **Senha padrão**: `admin`

> [!IMPORTANT]
> Altere a senha padrão logo após o primeiro acesso ou gere um novo hash Argon2id via `tuxfrw-web --hash-password <NOVA_SENHA>` para substituir no `/etc/tuxfrw-nft/config.toml`.
