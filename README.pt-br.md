# TuxFrw-NFT

> **A ferramenta definitiva de automação e gerenciamento de firewall Linux com Netfilter/nftables.**  
> *Versão 5.1*

[![Licença: GPLv2](https://img.shields.io/badge/License-GPLv2-blue.svg)](LICENSE)
[![Netfilter](https://img.shields.io/badge/Netfilter-nftables-orange.svg)](https://wiki.nftables.org/)
[![Dual-Stack](https://img.shields.io/badge/Dual--Stack-IPv4%20%2F%20IPv6-brightgreen.svg)](#)
[![Docker](https://img.shields.io/badge/Docker-Native%20Compatible-2496ED.svg)](#modo-docker-nativo-docker_support1)

---

## Idiomas / Languages
- 🇧🇷 [Português do Brasil (README.pt-br.md)](README.pt-br.md) | [Guia de Instalação (INSTALL.pt-br.md)](INSTALL.pt-br.md)
- 🇺🇸 [English (README.md)](README.md) | [Installation Guide (INSTALL.md)](INSTALL.md)

---

## Sumário
- [Visão Geral](#visão-geral)
- [Principais Recursos](#principais-recursos)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Requisitos](#requisitos)
- [Instalação Rápida](#instalação-rápida)
- [Utilização do CLI](#utilização-do-cli)
- [Modos de Operação](#modos-de-operação)
  - [Modo Docker Nativo (`DOCKER_SUPPORT="1"`)](#modo-docker-nativo-docker_support1)
  - [Modo Gateway Clássico (`DOCKER_SUPPORT="0"`)](#modo-gateway-clássico-docker_support0)
- [Documentação Técnica](#documentação-técnica)
- [Autoria e Créditos Históricos](#autoria-e-créditos-históricos)
- [Licença](#licença)

---

## Visão Geral

O **TuxFrw-NFT** é uma solução completa de automação e gerenciamento de firewall para GNU/Linux baseada exclusivamente no moderno subsistema **Netfilter/nftables**.

O sistema opera compilando dinamicamente um arquivo batch atômico de regras (`/etc/tuxfrw-nft/tuxfrw.nft`), injetado diretamente no kernel através do comando `/usr/sbin/nft -f`. Sua arquitetura modular foi concebida para que administradores de sistemas e engenheiros de redes possam definir políticas de segurança, interfaces e endereços IP de forma declarativa, legível e determinística.

---

## Principais Recursos

- **Compilação Atômica**: Regras compiladas em lote e aplicadas em uma única transação atômica no kernel, eliminando estados intermediários e perda de pacotes durante recargas.
- **Dual-Stack Nativo**: Tratamento unificado de tráfego IPv4 e IPv6 através da família `inet`, eliminando a redundância histórica entre `iptables` e `ip6tables`.
- **Modo Docker Nativo (`DOCKER_SUPPORT="1"`)**:
  - Blindagem completa do host no hook `INPUT`;
  - Filtragem granular de portas e origens de contêineres no hook `FORWARD` via módulo dedicado `rules/tf_DOCKER.mod` com prioridade superior (`priority -5`);
  - Operação não-destrutiva: elimina o uso de `flush ruleset`, preservando pontes virtuais (`docker0`, `br-*`), chains do daemon Docker e regras de NAT interno;
  - Saída irrestrita de contêineres e controle refinado sobre serviços publicados (`-p`).
- **uRPF Nativo e Anti-Spoofing Completo (FIB & BCP 38)**:
  - Strict uRPF via `fib saddr . iif oif` no hook `prerouting` para IPv4 e IPv6, descartando pacotes forjados antes das decisões de roteamento;
  - Egress Anti-Spoofing (BCP 38) garantindo que pacotes saindo da INT e DMZ para a Internet pertençam exclusivamente às sub-redes autorizadas;
  - Proteção contra amplificação e reflexão de DDoS na DMZ e isolamento estrito contra conexões não solicitadas da Internet para a rede interna (`EXT->INT`).
- **Pré-Filtragem Ingress (`netdev`)**:
  - Mitigação de anomalias de flags TCP (Xmas, NULL, SYN/FIN) e pacotes inválidos diretamente na placa de rede, poupando CPU;
  - Anti-spoofing precoce e controle de Bogons desacoplado das redes privadas (RFC 1918).
- **Stateful Packet Inspection**: Inspeção com controle de estado estrito via conntrack (`ct state established, related`) e descarte explícito de tráfego inválido.
- **Modo Gateway / Roteador Tradicional (`DOCKER_SUPPORT="0"`)**:
  - Matriz direcional completa: `EXT`, `INT`, `DMZ` e túneis VPN (`OpenVPN`, `PPTP`);
  - Suporte nativo a NAT em nftables: DNAT/Port Forwarding (`tf_NAT-IN.mod`) e SNAT/Masquerade (`tf_NAT-OUT.mod`).
- **Recargas Atômicas Dinâmicas**: Recarregue módulos isoladamente sem reiniciar todo o firewall (ex: `tuxfrw-nft load DOCKER`, `tuxfrw-nft load URPF`).
- **Integração Nativa com Systemd**: Unidade `tuxfrw-nft.service` ordenada antes de targets de rede para inicialização segura.

---

## Estrutura do Projeto

### Árvore do Repositório (Código-Fonte)

```text
tuxfrw-nft/
├── tuxfrw-nft                    # Script executável principal de controle (CLI)
├── tuxfrw.conf                   # Arquivo central de configuração e variáveis de rede
├── tuxfrw-nft.service            # Unidade de serviço para gerenciamento via systemd
├── install.sh                    # Script de instalação com validações e detecção de upgrade
├── tf_BASE.mod                   # Núcleo do firewall (tabelas, compilação atômica e limpeza segura)
├── tf_KERNEL.mod                 # Carga de módulos do kernel e controle de IP forwarding
├── rules/                        # Módulos especializados de regras Netfilter/nftables
│   ├── tf_INPUT.mod              # Proteção e filtragem do host local (hook input)
│   ├── tf_OUTPUT.mod             # Políticas e exceções de tráfego de saída (hook output)
│   ├── tf_DOCKER.mod             # Políticas para contêineres Docker (FORWARD priority -5)
│   ├── tf_NETDEV.mod             # Pré-filtragem ingress em interfaces físicas (netdev)
│   ├── tf_FORWARD.mod            # Roteamento e matriz de encaminhamento (Modo Gateway)
│   ├── tf_MANGLE.mod             # Manipulação e ajuste de pacotes (MSS clamping, etc.)
│   ├── tf_NAT-IN.mod             # Port Forwarding / DNAT em PREROUTING
│   ├── tf_NAT-OUT.mod            # Masquerade / SNAT em POSTROUTING
│   ├── tf_INT-EXT.mod            # Tráfego da rede interna (INT) para a Internet (EXT)
│   ├── tf_EXT-INT.mod            # Tráfego da Internet (EXT) para a rede interna (INT)
│   ├── tf_INT-DMZ.mod            # Tráfego da rede interna (INT) para a DMZ
│   ├── tf_DMZ-INT.mod            # Tráfego da DMZ para a rede interna (INT)
│   ├── tf_EXT-DMZ.mod            # Acessos da Internet (EXT) aos servidores da DMZ
│   ├── tf_DMZ-EXT.mod            # Acessos dos servidores da DMZ para a Internet (EXT)
│   ├── tf_INT-VPN.mod            # Tráfego da rede interna (INT) para túneis VPN
│   ├── tf_VPN-INT.mod            # Tráfego de túneis VPN para a rede interna (INT)
│   ├── tf_EXT-VPN.mod            # Tráfego da Internet (EXT) para túneis VPN
│   ├── tf_VPN-EXT.mod            # Tráfego de túneis VPN para a Internet (EXT)
│   ├── tf_DMZ-VPN.mod            # Tráfego da DMZ para túneis VPN
│   └── tf_VPN-DMZ.mod            # Tráfego de túneis VPN para a DMZ
├── manual/                       # Manuais técnicos aprofundados
│   ├── tuxfrw-manual-5.1-pt-br.md  # Manual técnico completo em Português do Brasil
│   └── tuxfrw-manual-5.1-en.md     # Manual técnico completo em Inglês
├── README.md & README.pt-br.md   # Documentação principal do projeto (EN / PT-BR)
├── INSTALL.md & INSTALL.pt-br.md # Guias de instalação e validação (EN / PT-BR)
├── CHANGELOG.md                  # Histórico de alterações seguindo Keep a Changelog
├── CREDITS.md                    # Créditos históricos das versões legadas (IPTables/CFTK)
├── AUTHORS                       # Autor e mantenedor do projeto
├── LICENSE                       # Licença GNU General Public License v2 (GPLv2)
└── VERSION                       # Versão da release atual (5.1)
```

### Layout de Implantação no Sistema Operacional

Após a execução do `./install.sh`, os arquivos são distribuídos com permissões estritas no host:

| Caminho no Sistema | Permissão | Descrição |
| :--- | :--- | :--- |
| `/usr/sbin/tuxfrw-nft` | `0700` (`rwx------`) | Utilitário executável do CLI |
| `/etc/systemd/system/tuxfrw-nft.service` | `0644` (`rw-r--r--`) | Unidade de inicialização do systemd |
| `/etc/tuxfrw-nft/` | `0700` (`rwx------`) | Diretório de configuração e regras |
| `/etc/tuxfrw-nft/tuxfrw.conf` | `0600` (`rw-------`) | Configuração central do firewall |
| `/etc/tuxfrw-nft/tf_BASE.mod` | `0600` (`rw-------`) | Funções base e compilação do ruleset |
| `/etc/tuxfrw-nft/tf_KERNEL.mod` | `0600` (`rw-------`) | Módulos e parâmetros de kernel |
| `/etc/tuxfrw-nft/rules/*.mod` | `0600` (`rw-------`) | 20 módulos de regras especializadas |

---

## Requisitos

- **Sistema Operacional**: GNU/Linux (kernel 4.19 ou superior com suporte a `nf_tables`);
- **Utilitário nftables**: Pacote `nftables` instalado (`nft` versão 0.9.0 ou superior);
- **Shell**: Bash (`/bin/bash`);
- **Privilégios**: Acesso de superusuário (`root`).

---

## Instalação Rápida

> Consulte o arquivo [INSTALL.pt-br.md](INSTALL.pt-br.md) para o passo a passo completo e detalhado.

```bash
# 1. Clone o repositório
git clone https://github.com/gondimcodes/tuxfrw-nft.git
cd tuxfrw-nft

# 2. Execute o instalador como root
sudo ./install.sh

# 3. Configure suas variáveis e modo de operação
sudo nano /etc/tuxfrw-nft/tuxfrw.conf

# 4. Inicie em modo de teste
sudo tuxfrw-nft start

# 5. Após validar as regras e conectividade, habilite no boot
sudo systemctl enable tuxfrw-nft
```

---

## Utilização do CLI

O executável `/usr/sbin/tuxfrw-nft` suporta as seguintes operações:

| Comando | Descrição |
| :--- | :--- |
| `tuxfrw-nft start` | Compila os módulos e aplica atomicamente o ruleset no kernel |
| `tuxfrw-nft stop` | Remove com segurança as tabelas do TuxFrw (preservando o Docker) |
| `tuxfrw-nft restart` | Executa a sequência de `stop` seguida de `start` |
| `tuxfrw-nft status` | Exibe as tabelas e chains ativas compiladas pelo TuxFrw-NFT |
| `tuxfrw-nft load <MÓDULO>` | Recarrega atomicamente apenas o módulo informado |
| `tuxfrw-nft panic` | Bloqueio de emergência: descarta imediatamente todo o tráfego |
| `tuxfrw-nft natopen` | *(Modo Gateway)* Aplica regras dinâmicas de DNAT |

### Exemplos de Recarga Dinâmica

```bash
# Aplicar novas regras de contêineres após editar rules/tf_DOCKER.mod
tuxfrw-nft load DOCKER

# Recarregar regras de anti-spoofing / uRPF
tuxfrw-nft load URPF

# Atualizar proteções do host após editar rules/tf_INPUT.mod
tuxfrw-nft load INPUT

# Atualizar roteamento interno após editar rules/tf_INT-EXT.mod
tuxfrw-nft load INT-EXT
```

---

## Modos de Operação

### Modo Docker Nativo (`DOCKER_SUPPORT="1"`)
Ideal para servidores de aplicação que executam contêineres Docker. 
- O host físico é protegido no `INPUT`.
- O tráfego para os contêineres é filtrado no `FORWARD` antes das regras padrão do Docker através de `rules/tf_DOCKER.mod` (`priority -5`).
- Conexões de saída dos contêineres (`apt update`, consultas DNS) são mantidas intactas.
- O TuxFrw **não** executa `flush ruleset`, evitando quebrar as regras de bridge do Docker.

### Modo Gateway Clássico (`DOCKER_SUPPORT="0"`)
Ideal para roteadores corporativos e firewalls de borda.
- Habilita a matriz direcional completa de encaminhamento (`INT`, `EXT`, `DMZ`, VPNs).
- Carrega as regras de NAT (SNAT/Masquerade e DNAT/Port Forwarding).
- Gerencia o estado de `forwarding` no kernel através do `tf_KERNEL.mod`.

---

## Documentação Técnica

Guias aprofundados sobre arquitetura, boas práticas e diagnóstico:
- [Manual Completo do TuxFrw-NFT (Português)](manual/tuxfrw-manual-5.1-pt-br.md)
- [Complete TuxFrw-NFT Technical Manual (English)](manual/tuxfrw-manual-5.1-en.md)
- [Guia de Instalação (Português)](INSTALL.pt-br.md)
- [Installation Guide (English)](INSTALL.md)
- [Notas de Versão e Changelog](CHANGELOG.md)

---

## Autoria e Créditos Históricos

**The TuxFrw Team**
- **Marcelo Gondim** <gondim@gmail.com> (Autor e Mantenedor Principal - TuxFrw-NFT 5.1)

Reconhecimentos e contribuições para as versões legadas do projeto (Netfilter/IPTables e Conectiva CFTK) estão documentados no arquivo [CREDITS.md](CREDITS.md).

Repositório Oficial: [https://github.com/gondimcodes/tuxfrw-nft](https://github.com/gondimcodes/tuxfrw-nft)

---

## Licença

Este projeto é software livre licenciado sob a **GNU General Public License v2 (GPLv2)**. Consulte o arquivo [LICENSE](LICENSE) para mais detalhes.
