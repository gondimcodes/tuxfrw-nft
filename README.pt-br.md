# TuxFrw-NFT

> **A ferramenta definitiva de automação e gerenciamento de firewall Linux com Netfilter/nftables.**  
> *Versão 5.0*

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
- [Autores e Créditos](#autores-e-créditos)
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
- **Pré-Filtragem Ingress (`netdev`)**:
  - Mitigação de anomalias de flags TCP (Xmas, NULL, SYN/FIN) e pacotes inválidos diretamente na placa de rede, poupando CPU;
  - Anti-spoofing e controle de Bogons desacoplado das redes privadas (RFC 1918).
- **Stateful Packet Inspection**: Inspeção com controle de estado estrito via conntrack (`ct state established, related`) e descarte explícito de tráfego inválido.
- **Modo Gateway / Roteador Tradicional (`DOCKER_SUPPORT="0"`)**:
  - Matriz direcional completa: `EXT`, `INT`, `DMZ` e túneis VPN (`OpenVPN`, `PPTP`);
  - Suporte nativo a NAT em nftables: DNAT/Port Forwarding (`tf_NAT-IN.mod`) e SNAT/Masquerade (`tf_NAT-OUT.mod`).
- **Recargas Atômicas Dinâmicas**: Recarregue módulos isoladamente sem reiniciar todo o firewall (ex: `tuxfrw-nft load DOCKER`).
- **Integração Nativa com Systemd**: Unidade `tuxfrw-nft.service` ordenada antes de targets de rede para inicialização segura.

---

## Estrutura do Projeto

```text
/usr/sbin/tuxfrw-nft          # Script executável principal de controle (CLI)
/etc/systemd/system/          # tuxfrw-nft.service (unidade systemd)
/etc/tuxfrw-nft/
  ├── tuxfrw.conf             # Configuração central e variáveis de rede
  ├── tf_BASE.mod             # Funções essenciais, tabelas e compilação do batch
  ├── tf_KERNEL.mod           # Módulos de kernel e controle de IP forwarding
  └── rules/                  # Módulos especializados de regras
      ├── tf_INPUT.mod        # Proteção e filtragem do host local (INPUT)
      ├── tf_OUTPUT.mod       # Políticas e exceções de tráfego de saída (OUTPUT)
      ├── tf_DOCKER.mod       # Políticas de acesso aos contêineres Docker (FORWARD)
      ├── tf_NETDEV.mod       # Pré-filtragem ingress em nível de placa de rede
      ├── tf_FORWARD.mod      # Roteamento e encaminhamento entre zonas (Gateway)
      ├── tf_INT-EXT.mod      # Tráfego da rede interna para a Internet
      ├── tf_EXT-INT.mod      # Tráfego da Internet para a rede interna
      ├── tf_INT-DMZ.mod      # Tráfego da rede interna para a DMZ
      ├── tf_DMZ-INT.mod      # Tráfego da DMZ para a rede interna
      ├── tf_EXT-DMZ.mod      # Acessos da Internet aos servidores da DMZ
      ├── tf_DMZ-EXT.mod      # Acessos dos servidores da DMZ para a Internet
      ├── tf_NAT-IN.mod       # Port Forwarding / DNAT em PREROUTING
      ├── tf_NAT-OUT.mod      # Masquerade / SNAT em POSTROUTING
      ├── tf_OPENVPN.mod      # Regras para túneis OpenVPN
      └── tf_PPTP.mod         # Regras para túneis PPTP/GRE
```

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
- [Manual Completo do TuxFrw-NFT (Português)](manual/tuxfrw-manual-5.00-br.txt)
- [Complete TuxFrw-NFT Technical Manual (English)](manual/tuxfrw-manual-5.00-en.txt)
- [Guia de Instalação (Português)](INSTALL.pt-br.md)
- [Installation Guide (English)](INSTALL.md)
- [Notas de Versão e Changelog](CHANGELOG.md)

---

## Autores e Créditos

**The TuxFrw Team**
- **Marcelo Gondim** <gondim@gmail.com> (Autor e Mantenedor Principal)
- Colaboradores reconhecidos no arquivo [CREDITS](CREDITS).

Repositório Oficial: [https://github.com/gondimcodes/tuxfrw-nft](https://github.com/gondimcodes/tuxfrw-nft)

---

## Licença

Este projeto é software livre licenciado sob a **GNU General Public License v2 (GPLv2)**. Consulte o arquivo [LICENSE](LICENSE) para mais detalhes.
