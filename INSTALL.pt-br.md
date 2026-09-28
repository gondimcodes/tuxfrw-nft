# Instalação do TuxFrw-NFT

> Este documento descreve o procedimento passo a passo para instalação, configuração inicial, validação e ativação do **TuxFrw-NFT** em servidores GNU/Linux.

Para mais detalhes sobre regras e arquitetura, consulte:
- [README em Português](README.pt-br.md)
- [Manual Técnico Completo](manual/tuxfrw-manual-5.00-br.txt)

---

## Sumário
- [1. Pré-Requisitos](#1-pré-requisitos)
- [2. Procedimento de Instalação](#2-procedimento-de-instalação)
- [3. Configuração Inicial](#3-configuração-inicial)
- [4. Teste em Tempo de Execução (Runtime)](#4-teste-em-tempo-de-execução-runtime)
- [5. Habilitação no Boot (Systemd)](#5-habilitação-no-boot-systemd)
- [6. Desinstalação](#6-desinstalação)

---

## 1. Pré-Requisitos

Antes de iniciar a instalação, certifique-se de que o sistema atende aos seguintes requisitos:

| Componente | Requisito Mínimo | Observações |
| :--- | :--- | :--- |
| **Sistema Operacional** | GNU/Linux | Debian, Ubuntu, AlmaLinux, Rocky Linux, RHEL |
| **Kernel Linux** | 4.19 ou superior | Módulo `nf_tables` ativo no kernel |
| **Utilitário nftables** | Pacote `nftables` (nft ≥ 0.9.0) | Necessário para compilação atômica |
| **Shell** | Bash (`/bin/bash`) | Interpretador padrão do sistema |
| **Privilégios** | `root` ou `sudo` | Necessário para aplicar regras de rede |

### Instalação do pacote nftables

- **Debian / Ubuntu**:
  ```bash
  sudo apt update && sudo apt install nftables -y
  ```

- **AlmaLinux / Rocky Linux / RHEL / CentOS**:
  ```bash
  sudo dnf install nftables -y
  ```

---

## 2. Procedimento de Instalação

1. Clone o repositório no servidor:
   ```bash
   git clone https://github.com/gondimcodes/tuxfrw-nft.git
   cd tuxfrw-nft
   ```

2. Execute o script de instalação como root:
   ```bash
   sudo ./install.sh
   ```

O instalador realizará as seguintes ações automatizadas:
- Validação dos pré-requisitos (`bash`, `nft`, utilitário `install`);
- Criação do diretório de configurações `/etc/tuxfrw-nft` com permissão restrita (`0700`);
- Instalação dos módulos de regras e arquivos `.conf` com permissões restritas (`0600`);
- Instalação do script executável em `/usr/sbin/tuxfrw-nft` (`0700`);
- Instalação da unidade systemd `/etc/systemd/system/tuxfrw-nft.service` e execução de `systemctl daemon-reload`;
- Detecção de instalações prévias com solicitação de confirmação explícita antes de qualquer sobrescrita.

> [!IMPORTANT]
> **Prevenção de Lockout**: Por segurança, o instalador **NÃO** habilita o serviço no boot (`systemctl enable`) automaticamente. Isso evita a perda de acesso remoto (SSH) antes da devida revisão e teste das regras pelo administrador.

---

## 3. Configuração Inicial

Antes de iniciar o serviço pela primeira vez:

### 1) Edite o arquivo `/etc/tuxfrw-nft/tuxfrw.conf`

```bash
sudo nano /etc/tuxfrw-nft/tuxfrw.conf
```

- **Defina o modo operacional**:
  - `DOCKER_SUPPORT="1"`: Servidores de aplicação com Docker.
  - `DOCKER_SUPPORT="0"`: Modo tradicional de Gateway/Roteador com NAT.
- **Configure as interfaces de rede**:
  - Exemplo: `IF_EXT="eth0"`, `IF_INT="eth1"`, `IF_DMZ="eth2"`.
- **Defina acessos administrativos**:
  - Configure `ADMIN_IPS` e `ADMIN_PORTS` para liberar o acesso ao SSH e outros serviços de gerência.
- **Revise a flag BOGONS**:
  - O padrão é `BOGONS="0"` (desabilitado), preservando a comunicação com servidores de DNS locais e redes privadas (RFC 1918).

### 2) Revise os módulos de regras em `/etc/tuxfrw-nft/rules/`

- **Host local**: `/etc/tuxfrw-nft/rules/tf_INPUT.mod` (SSH, ICMP, DNS e serviços locais).
- **Modo Docker**: `/etc/tuxfrw-nft/rules/tf_DOCKER.mod` (liberações pontuais de portas de contêineres).
- **Modo Gateway**: `/etc/tuxfrw-nft/rules/tf_FORWARD.mod`, `tf_NAT-IN.mod` e `tf_NAT-OUT.mod`.

---

## 4. Teste em Tempo de Execução (Runtime)

> [!TIP]
> Mantenha sempre uma sessão SSH de contingência aberta em outra janela de terminal ao testar regras pela primeira vez.

1. Inicie o firewall manualmente:
   ```bash
   sudo tuxfrw-nft start
   ```

2. Verifique se as tabelas foram carregadas corretamente:
   ```bash
   sudo tuxfrw-nft status
   ```

3. Inspecione o conjunto de regras ativo no kernel:
   ```bash
   sudo nft list ruleset
   ```

4. Valide a conectividade com a Internet, acesso SSH e funcionamento de contêineres Docker (se aplicável).

---

## 5. Habilitação no Boot (Systemd)

Após validar o funcionamento e confirmar que não há bloqueios indevidos, habilite o TuxFrw-NFT para iniciar automaticamente com o sistema:

```bash
sudo systemctl enable tuxfrw-nft
```

Comandos úteis via systemd:
```bash
sudo systemctl start tuxfrw-nft
sudo systemctl stop tuxfrw-nft
sudo systemctl restart tuxfrw-nft
sudo systemctl status tuxfrw-nft
```

---

## 6. Desinstalação

Para remover completamente o TuxFrw-NFT do sistema:

1. Pare o serviço e limpe as regras ativas:
   ```bash
   sudo tuxfrw-nft stop
   ```

2. Desabilite e remova a unidade do systemd:
   ```bash
   sudo systemctl disable tuxfrw-nft
   sudo rm -f /etc/systemd/system/tuxfrw-nft.service
   sudo systemctl daemon-reload
   ```

3. Remova o executável e o diretório de configurações:
   ```bash
   sudo rm -f /usr/sbin/tuxfrw-nft
   sudo rm -rf /etc/tuxfrw-nft
   ```
