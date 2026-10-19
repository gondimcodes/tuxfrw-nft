# Manual Técnico do TuxFrw-NFT

> **Guia Completo de Arquitetura, Operação, Integração Docker e Diagnóstico**  
> *Versão 6.0.0*

---

## Sumário
- [1. Introdução](#1-introdução)
  - [Zonas de Rede](#zonas-de-rede)
- [2. Recursos Arquiteturais](#2-recursos-arquiteturais)
- [3. Estrutura Modular e Fluxo de Execução](#3-estrutura-modular-e-fluxo-de-execução)
- [4. Detalhamento dos Componentes](#4-detalhamento-dos-componentes)
- [5. Operação e Linha de Comando (CLI)](#5-operação-e-linha-de-comando-cli)
- [6. Modo de Compatibilidade com Docker (`DOCKER_SUPPORT="1"`)](#6-modo-de-compatibilidade-com-docker-docker_support1)
  - [O Problema de Segurança Padrão do Docker](#o-problema-de-segurança-padrão-do-docker)
  - [A Solução Arquitetural do TuxFrw-NFT](#a-solução-arquitetural-do-tuxfrw-nft)
  - [Exemplos Práticos de Regras para Contêineres](#exemplos-práticos-de-regras-para-contêineres)
- [7. Proteção de Servidores Web com Proxies Cloudflare (Anti-Bypass)](#7-proteção-de-servidores-web-com-proxies-cloudflare-anti-bypass)
- [8. Coexistência Nativa com Fail2ban e Daemons de Terceiros (Zero-Touch)](#8-coexistência-nativa-com-fail2ban-e-daemons-de-terceiros-zero-touch)
- [9. Mitigação de SYN Flood com TCP SYNPROXY](#9-mitigação-de-syn-flood-com-tcp-synproxy)
- [10. Matriz Direcional de VPNs (OpenVPN, WireGuard, L2TP/IPsec)](#10-matriz-direcional-de-vpns-openvpn-wireguard-l2tpipsec)
- [11. Diagnóstico e Tratamento de Falhas](#11-diagnóstico-e-tratamento-de-falhas)
- [12. Instalação e Inicialização com Systemd](#12-instalação-e-inicialização-com-systemd)
- [13. Referências e Créditos](#13-referências-e-créditos)

---

## 1. Introdução

O **TuxFrw-NFT** consiste em uma infraestrutura modular em shell scripts que gera definições e regras determinísticas para o subsistema **Netfilter/nftables** do Linux. O projeto foi projetado para facilitar a administração, auditoria e manutenção de segurança em servidores de alta criticidade em produção.

O firewall opera compilando dinamicamente um batch atômico de regras executado diretamente pelo utilitário do kernel (`/usr/sbin/nft -f`). O TuxFrw-NFT é nativamente **Dual-Stack** (IPv4 e IPv6 simultaneamente em todas as tabelas da família `inet`) e atua com excelência tanto em **servidores de aplicação com Docker** quanto em **gateways corporativos de borda** que interligam múltiplas zonas:

### Zonas de Rede

| Zona | Identificador | Descrição e Finalidade |
| :--- | :--- | :--- |
| **Externa** | `EXT` | Interface voltada para a Internet ou rede não confiável. Aplica pré-filtragem ingress (`netdev`) contra anomalias de flags TCP, varreduras e spoofing. |
| **Desmilitarizada** | `DMZ` | Zona semi-protegida para servidores públicos (HTTP, HTTPS, DNS, SMTP). Isola estritamente a DMZ do acesso irrestrito à rede interna. |
| **Interna** | `INT` | Rede corporativa local (LAN). Controla tráfego originado internamente para a Internet e DMZ, registrando e bloqueando tentativas indevidas. |

---

## 2. Recursos Arquiteturais

### 1. Stateful Packet Inspection (`conntrack`)
Controle rigoroso de estado de conexões (`ct state established, related`) tanto para IPv4 quanto para IPv6. Descarta pacotes inválidos (`ct state invalid`) e dispensa a necessidade de criação manual de regras reversas para pacotes de resposta.

### 2. Pré-Filtragem Ingress com Netdev (`tf_NETDEV.mod`)
Filtragem na camada de driver/interface física antes mesmo da pilha IP do kernel. Bloqueia pacotes malformados com anomalias de flags TCP (Xmas scans, NULL scans, SYN/FIN simultâneos) com custo desprezível de processamento de CPU.

### 3. Dual-Stack Unificado (`inet filter`)
Diferente dos sistemas legados de IPTables que exigiam scripts separados para IPv4 (`iptables`) e IPv6 (`ip6tables`), o TuxFrw-NFT consolida todas as políticas na família unificada `inet`, aplicando regras simultaneamente a ambos os protocolos.

### 4. Network Address Translation (NAT via nftables)
No modo clássico de gateway (`DOCKER_SUPPORT="0"`), fornece suporte robusto a:
- **SNAT / Masquerade**: Tradução de saída em `POSTROUTING` (`tf_NAT-OUT.mod`);
- **DNAT / Port Forwarding**: Redirecionamento de portas de entrada em `PREROUTING` (`tf_NAT-IN.mod`).

### 5. Suporte Nativo a Ambientes Docker (`DOCKER_SUPPORT="1"`)
Permite operar em servidores com contêineres Docker sem interferir nas regras de NAT e bridges virtuais (`docker0`, `br-*`) criadas pelo daemon do Docker, blindando o host físico e controlando o acesso a portas publicadas no hook `FORWARD` em prioridade superior (`priority -5`).

### 6. Anti-Spoofing Completo (uRPF via FIB e BCP 38)
- **Strict uRPF Dinâmico em PREROUTING**: Validação de rota reversa (`fib saddr . iif oif missing drop`) tanto para IPv4 quanto para IPv6 no ponto de ingresso, neutralizando pacotes externos que forjam IPs internos ou não roteáveis antes de qualquer decisão de roteamento.
- **Egress Anti-Spoofing (BCP 38 / RFC 2827)**: Garantia direcional em `INT-EXT` e `DMZ-EXT` de que máquinas internas e servidores da DMZ só podem originar tráfego com IPs pertencentes aos seus respectivos prefixos alocados.
- **Mitigação de Amplificação e Reflexão DDoS**: Bloqueio de novas conexões não solicitadas da Internet para a rede interna (`EXT->INT`), bloqueio de portas vetores clássicas de reflexão UDP na DMZ (Memcached, NTP, SSDP, SNMP, etc.) e rate-limiting para tráfego DNS legítimo.

### 7. Mitigação Avançada de SYN Flood via TCP SYNPROXY
Proteção de serviços públicos contra ataques volumétricos de exaustão de estado (SYN Flood) diretamente pelo kernel Linux via SYN Cookies criptográficos (RFC 4987). Opera em estágio `PREROUTING raw` com `notrack`, aliviando o conntrack até a confirmação do handshake. Suporte completo a Dual-Stack (`synproxy-v4` com MSS 1460 e `synproxy-v6` com MSS 1440), ajuste automático de sysctls (`nf_conntrack_tcp_loose=0`, `tcp_syncookies=1`, `tcp_timestamps=1`) e recarga atômica com `tuxfrw-nft load SYNPROXY`.

### 8. Matriz Direcional de VPNs Modernas (OpenVPN, WireGuard, L2TP/IPsec)
Suporte unificado e seguro aos três principais padrões de VPN da atualidade, com eliminação definitiva do protocolo legado e inseguro PPTP. Permite roteamento granular e isolamento entre túneis e as redes locais (`INT2VPN`, `VPN2INT`, `EXT2VPN`, `VPN2EXT`, `DMZ2VPN`, `VPN2DMZ`), além de autoloader condicional de módulos de kernel (`wireguard`, `tun`, `ppp_generic`, `l2tp_core`, `esp4`, `esp6`).

### 9. Dual-Stack ICMPv6 e Path MTU Discovery (RFC 8201)
Como roteadores IPv6 não realizam fragmentação em trânsito, a cadeia `FORWARD` do TuxFrw-NFT permite expressamente mensagens `icmpv6 type packet-too-big`, prevenindo o problema de "IPv6 Black Hole" (onde sessões TCP com pacotes grandes travam após o handshake).

### 10. Princípio de Security by Default e Hardening Local
Todas as portas de serviços em DMZ e regras de 1:1 NAT vêm comentadas por padrão como exemplos didáticos, impedindo abertura acidental de portas para endereços arbitrários. Além disso, protocolos de descoberta local (mDNS 5353 UDP e SSDP 1900 UDP) são restritos estritamente à rede interna (`INT_IFACE`), bloqueando enumeração de serviços na WAN.

---

## 3. Estrutura Modular e Fluxo de Execução

```text
                                /usr/sbin/tuxfrw-nft
                                         │
                                /etc/tuxfrw-nft/tuxfrw.conf
                                         │
                                /etc/tuxfrw-nft/tf_BASE.mod
                                         │
     ┌───────────────────────────────────┼───────────────────────────────────┐
     │                                   │                                   │
 tf_KERNEL.mod                   tf_INPUT.mod / tf_OUTPUT.mod          tf_NETDEV.mod
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 │ (se DOCKER_SUPPORT="1")                       │ (se DOCKER_SUPPORT="0")
                 │                                               │
           tf_DOCKER.mod                                   tf_FORWARD.mod
         (FORWARD prio -5)                                (FORWARD prio 0)
                                                                 │
                                       ┌─────────────────────────┼─────────────────────────┐
                                       │            │            │            │            │
                                   tf_INT-EXT   tf_EXT-INT   tf_INT-DMZ   tf_DMZ-INT   tf_DMZ-EXT
                                       │            │            │            │            │
                                   tf_EXT-DMZ   tf_INT-VPN   tf_VPN-INT   tf_EXT-VPN   tf_VPN-EXT
                                                                 │
                                                            tf_DMZ-VPN / tf_VPN-DMZ
                                                                 │
                                                            tf_MANGLE.mod
                                                                 │
                                                       tf_NAT-IN / tf_NAT-OUT
```

---

## 4. Detalhamento dos Componentes

| Arquivo / Módulo | Função e Responsabilidade |
| :--- | :--- |
| `/usr/sbin/tuxfrw-nft` | Binário executável do CLI. Processa argumentos (`start`, `stop`, `load`, etc.) e gerencia a invocação do compilador. |
| `/etc/tuxfrw-nft/tuxfrw.conf` | Arquivo central de parametrização de rede, IPs administrativos, interfaces e modo de suporte a Docker. |
| `/etc/tuxfrw-nft/tf_BASE.mod` | Núcleo do firewall. Orquestra a montagem de tabelas, limpeza segura de ruleset (`clear_rules`) e compilação do batch. |
| `/etc/tuxfrw-nft/tf_KERNEL.mod` | Carga seletiva de módulos de kernel (`modprobe`) e habilitação/desabilitação de `net.ipv4/ipv6.conf.all.forwarding`. |
| `rules/tf_INPUT.mod` | Regras do hook de entrada (`INPUT`, policy drop) protegendo o host físico: loopback, conexões estabelecidas, ICMPv4/v6, DHCP e SSH. |
| `rules/tf_OUTPUT.mod` | Regras do hook de saída (`OUTPUT`) para pacotes originados localmente no servidor. |
| `rules/tf_DOCKER.mod` | Módulo ativo no modo Docker (`DOCKER_SUPPORT="1"`). Regras de tráfego de contêineres na chain `FORWARD` em prioridade `-5`. |
| `rules/tf_FORWARD.mod` | Roteamento e encaminhamento clássico entre zonas (`DOCKER_SUPPORT="0"`). Realiza saltos para as chains direcionais. |
| `rules/tf_NETDEV.mod` | Pré-filtragem no estágio ingress de interfaces físicas contra anomalias de flags TCP e pacotes spoofados. |
| `rules/tf_NAT-IN.mod` | Regras de DNAT (Port Forwarding em `PREROUTING`). |
| `rules/tf_NAT-OUT.mod` | Regras de SNAT (Masquerade em `POSTROUTING`). |
| `/etc/systemd/system/tuxfrw-nft.service` | Unidade systemd configurada para proteção antecipada no ciclo de boot (`Before=network-pre.target`). |

---

## 5. Operação e Linha de Comando (CLI)

O comando `tuxfrw-nft` deve ser executado com privilégios de `root`:

### 1. Iniciar o Firewall
```bash
sudo tuxfrw-nft start
# ou: sudo systemctl start tuxfrw-nft
```
Compila todos os módulos em `/etc/tuxfrw-nft/tuxfrw.nft` e aplica atomicamente no kernel via `nft -f`.

### 2. Parar o Firewall
```bash
sudo tuxfrw-nft stop
# ou: sudo systemctl stop tuxfrw-nft
```
Remove de forma segura as tabelas do TuxFrw (`inet filter`, `netdev filter`, `inet mangle`) sem derrubar as chains ou bridges virtuais do Docker.

### 3. Consultar Estado e Regras Ativas
```bash
sudo tuxfrw-nft status
```
Exibe o ruleset ativo carregado na memória do subsistema nftables.

### 4. Recarga Dinâmica Atômica de um Módulo Específico
O comando `load` recompila e reaplica atomicamente apenas a chain do módulo informado, sem interromper as outras chains do firewall:
```bash
sudo tuxfrw-nft load INPUT     # Recarrega tf_INPUT.mod (ex: novos IPs de SSH)
sudo tuxfrw-nft load SYNPROXY  # Recarrega regras de SYNPROXY e chain prerouting raw
sudo tuxfrw-nft load DOCKER    # Recarrega tf_DOCKER.mod (ex: liberação de portas de contêineres)
sudo tuxfrw-nft load URPF      # Recarrega chain PREROUTING com uRPF anti-spoofing
sudo tuxfrw-nft load OUTPUT    # Recarrega tf_OUTPUT.mod
sudo tuxfrw-nft load NETDEV    # Recarrega tf_NETDEV.mod
sudo tuxfrw-nft load INT-EXT   # Recarrega tf_INT-EXT.mod
sudo tuxfrw-nft load NAT-IN    # Recarrega tf_NAT-IN.mod
```

### 5. Modo Pânico (Lockdown Imediato)
```bash
sudo tuxfrw-nft panic
```
Interrompe imediatamente todo o tráfego do sistema e encerra conexões ativas.

### 6. Atualização de IPs dos Proxies Cloudflare (`cf-update`)
```bash
sudo tuxfrw-nft cf-update
```
Consulta os endpoints oficiais da Cloudflare (`ips-v4` e `ips-v6`), valida rigorosamente a sintaxe CIDR de cada prefixo contra injeção de dados, grava atomicamente em `/etc/tuxfrw-nft/cloudflare.conf` (`0600`) e disponibiliza as variáveis `CF_IPV4` / `CF_IPV6` e definições `$cf_ipv4` / `$cf_ipv6` para regras de firewall.

---

## 6. Modo de Compatibilidade com Docker (`DOCKER_SUPPORT="1"`)

### O Problema de Segurança Padrão do Docker
O daemon do Docker gerencia seu próprio roteamento interno no Netfilter. Sempre que um contêiner é publicado (ex: `docker run -p 3000:3000 ...`), o Docker insere uma regra de DNAT no `PREROUTING` e entrega o pacote para ser encaminhado na chain `FORWARD`.

1. **Sem TuxFrw-NFT**: O Docker aceita qualquer pacote na chain `FORWARD` por padrão, deixando o serviço do contêiner exposto para toda a Internet (`0.0.0.0/0`), ignorando as proteções tradicionais que o administrador configurou no `INPUT`.
2. **Com firewalls legados (IPTables)**: Executar um comando de reinicialização (`flush ruleset`) destruía as tabelas e bridges virtuais do Docker, paralisando todos os contêineres até a reinicialização do daemon `dockerd`.

### A Solução Arquitetural do TuxFrw-NFT
- **Limpeza Cirúrgica**: O TuxFrw-NFT remove exclusivamente suas próprias tabelas (`inet filter`, `netdev filter`, `inet mangle`), mantendo as chains do Docker 100% íntegras.
- **Prioridade Negativa (`priority -5`)**: No nftables, o hook forward padrão roda com prioridade 0 (`NF_IP_PRI_FILTER`). Ao atribuir prioridade `-5` à chain `FORWARD` do módulo `rules/tf_DOCKER.mod`, garantimos que o TuxFrw avalia e bloqueia o tráfego **antes** que as regras permissivas padrão do Docker recebam o pacote.

### Exemplos Práticos de Regras para Contêineres

Edite o arquivo `/etc/tuxfrw-nft/rules/tf_DOCKER.mod`:

#### Exemplo 1: Liberar porta de um contêiner (ex: porta 3000) apenas para um IP ou rede confiável
```bash
# Permite acesso à porta 3000 apenas a partir do IP autorizado
$NFT 'add rule inet filter FORWARD ip saddr 203.0.113.50 tcp dport 3000 counter accept'

# Bloqueia qualquer outro acesso externo à porta 3000
$NFT 'add rule inet filter FORWARD tcp dport 3000 counter drop'
```

#### Exemplo 2: Liberar contêiner público (servidor web HTTP/HTTPS)
```bash
$NFT 'add rule inet filter FORWARD tcp dport { 80, 443 } counter accept'
```

#### Aplicando as alterações sem downtime
Após editar o módulo `rules/tf_DOCKER.mod`, aplique instantaneamente:
```bash
sudo tuxfrw-nft load DOCKER
```

---

## 7. Proteção de Servidores Web com Proxies Cloudflare (Anti-Bypass)

Quando servidores web (Nginx, Apache, Caddy, Traefik) operam atrás da Cloudflare, atacantes frequentemente tentam atingir o IP real do servidor diretamente para contornar proteções de WAF, anti-DDoS e rate-limiting.

O TuxFrw-NFT oferece suporte nativo para isolar o tráfego HTTP/HTTPS (portas 80 e 443) exclusivamente para os proxies reversos da Cloudflare.

### 1. Atualizando as faixas de IP
Execute o comando:
```bash
sudo tuxfrw-nft cf-update
```
Isso baixa os blocos IPv4 e IPv6 oficiais, valida cada prefixo via regex e grava de forma atômica no arquivo satélite `/etc/tuxfrw-nft/cloudflare.conf` (`0600`), disponibilizando `$cf_ipv4` e `$cf_ipv6` no batch do nftables.

### 2. Uso no Host Físico (`rules/tf_INPUT.mod`)
Descomente ou inclua no final de `tf_INPUT.mod`:
```bash
if [ "$CF_IPV4" != "" -a "$EXT_IFACE" != "" ]; then
   $NFT "add rule inet filter INPUT iif $EXT_IFACE ip saddr \$cf_ipv4 tcp dport { 80, 443 } counter accept"
fi
if [ "$CF_IPV6" != "" -a "$EXT_IFACE" != "" ]; then
   $NFT "add rule inet filter INPUT iif $EXT_IFACE ip6 saddr \$cf_ipv6 tcp dport { 80, 443 } counter accept"
fi
```
Recarregue a chain de entrada:
```bash
sudo tuxfrw-nft load INPUT
```

### 3. Uso em Contêineres Docker (`rules/tf_DOCKER.mod`)
No módulo de contêineres, restrinja o encaminhamento das portas 80/443 apenas para a Cloudflare e descarte o tráfego direto de terceiros:
```bash
if [ "$CF_IPV4" != "" ]; then
   $NFT "add rule inet filter FORWARD ip saddr \$cf_ipv4 tcp dport { 80, 443 } counter accept"
fi
if [ "$CF_IPV6" != "" ]; then
   $NFT "add rule inet filter FORWARD ip6 saddr \$cf_ipv6 tcp dport { 80, 443 } counter accept"
fi
$NFT "add rule inet filter FORWARD tcp dport { 80, 443 } counter drop"
```
Recarregue a chain de contêineres:
```bash
sudo tuxfrw-nft load DOCKER
```

### 4. Agendamento Automático via Cron
Para manter as faixas sempre atualizadas automaticamente (ex: semanalmente), adicione ao cron do sistema (`/etc/cron.weekly/tuxfrw-cf-update` ou `crontab -e` do root):
```bash
0 3 * * 0 /usr/sbin/tuxfrw-nft cf-update >/dev/null 2>&1 && /usr/sbin/tuxfrw-nft restart >/dev/null 2>&1
```

---

---

## 8. Coexistência Nativa com Fail2ban e Daemons de Terceiros (Zero-Touch)

A partir da versão 5.3, o TuxFrw-NFT opera com **isolamento cirúrgico de tabelas** e aboliu definitivamente o uso de `flush ruleset` global em todos os seus modos operacionais.

### Como Funciona a Coexistência Zero-Touch
1. **Preservação Total de Tabelas Alheias**:
   - Daemons como o **Fail2ban** (via `table inet f2b-table` ou `table ip filter`) e Docker criam e mantêm seus próprios namespaces no Netfilter.
   - O TuxFrw-NFT limpa e recria estritamente suas próprias tabelas (`inet filter`, `netdev filter`, `inet mangle`, `ip nat`, `ip6 nat`), garantindo que sets de IPs banidos e chains do Fail2ban permaneçam **100% intactos** no kernel durante comandos como `tuxfrw-nft restart`, `tuxfrw-nft stop` ou `tuxfrw-nft load INPUT`.
2. **Encadeamento de Prioridades no Netfilter**:
   - O Fail2ban configura suas chains com prioridade `-1` (`priority filter - 1`).
   - A chain `INPUT` do TuxFrw-NFT roda com prioridade `0` (`NF_IP_PRI_FILTER`).
   - O kernel avalia `-1` antes de `0`: conexões de IPs banidos pelo Fail2ban são rejeitadas ou descartadas imediatamente na borda, antes de consumir processamento das regras do TuxFrw.
3. **Ordem de Inicialização no Boot**:
   - A unidade `tuxfrw-nft.service` define `Before=network-pre.target shutdown.target fail2ban.service`, assegurando que o firewall base esteja consolidado antes que o Fail2ban inicialize suas jails.

---

## 9. Mitigação de SYN Flood com TCP SYNPROXY

A partir da versão 6.0.0, o TuxFrw-NFT implementa uma arquitetura modular de **TCP SYNPROXY**, permitindo que portas de serviços altamente expostos (ex: HTTP 80, HTTPS 443) resistam a ataques volumétricos de negação de serviço (SYN Flood) sem exaurir a tabela do conntrack.

### Como Funciona
1. **Marcação `notrack` em PREROUTING raw**:
   - Quando `SYNPROXY="1"`, o TuxFrw-NFT cria a chain `synproxy-prerouting` com prioridade `raw`.
   - Pacotes TCP SYN destinados às portas configuradas em `SYNPROXY_PORTS` são marcados com `notrack`, impedindo que o conntrack aloque sessões preliminares na memória.
2. **Handshake Simulado no Kernel**:
   - Ao atingir a chain `INPUT`, os objetos `synproxy-v4` (MSS 1460, WScale 7) e `synproxy-v6` (MSS 1440, WScale 7) respondem ao SYN com SYN Cookies criptográficos (RFC 4987).
   - Somente após o cliente comprovar legitimidade enviando o ACK final com o cookie válido, a conexão é inicializada para o socket local do serviço.
3. **Tuning Automático de Kernel via sysctl**:
   - O módulo `tf_KERNEL.mod` ativa automaticamente quando `SYNPROXY="1"`:
     - `net.netfilter.nf_conntrack_tcp_loose=0`: Exige handshake estrito para criação de sessões;
     - `net.ipv4.tcp_syncookies=1`: Habilita o algoritmo criptográfico de SYN cookies;
     - `net.ipv4.tcp_timestamps=1`: Codifica opções de Window Scale e SACK dentro dos timestamps TCP.

### Ativação no `tuxfrw.conf`
```bash
SYNPROXY="1"
SYNPROXY_PORTS="80, 443"
```
Para recarregar apenas o SYNPROXY:
```bash
sudo tuxfrw-nft load SYNPROXY
```

---

## 10. Matriz Direcional de VPNs (OpenVPN, WireGuard, L2TP/IPsec)

O TuxFrw-NFT 6.0.0 eliminou definitivamente o suporte ao protocolo legado e vulnerável PPTP (porta 1723 / GRE), introduzindo suporte nativo completo ao trio moderno de VPNs:

### 1. Padrões Suportados e Variáveis no `tuxfrw.conf`
- **OpenVPN**: `OpenVPN_IFACE="tun+"`, `OpenVPN_PORT="1194"`, `OpenVPN_PROTO="udp"`, `OpenVPN_PEER_IP` (opcional).
- **WireGuard**: `WG_IFACE="wg+"`, `WG_PORT="51820"`, `WG_PEER_IP` (opcional).
- **L2TP/IPsec**: `L2TP_IFACE="ppp+"`, `L2TP_PEER_IP` (opcional). Aceita UDP 500 (IKE), UDP 4500 (NAT-T), UDP 1701 (L2TP) e protocolo IP 50 (ESP Dual-Stack).

### 2. Matriz Direcional de Roteamento no FORWARD
Quando uma ou mais interfaces de VPN são configuradas, o TuxFrw-NFT cria e vincula dinamicamente as chains direcionais de tráfego entre a VPN e as zonas do firewall:
- **`VPN->*`**: `VPN2INT` (para Intranet), `VPN2EXT` (para Internet), `VPN2DMZ` (para DMZ).
- **`*->VPN`**: `INT2VPN` (da Intranet), `EXT2VPN` (da Internet), `DMZ2VPN` (da DMZ).

### 3. Autoloader de Módulos de Kernel
O TuxFrw-NFT carrega automaticamente os drivers necessários conforme as VPNs ativas (`wireguard`, `tun`, `ppp_generic`, `l2tp_core`, `esp4`, `esp6`).

---

## 11. Diagnóstico e Tratamento de Falhas

O TuxFrw-NFT gera o arquivo batch `/etc/tuxfrw-nft/tuxfrw.nft` e o submete atomicamente ao utilitário `nft`. Se houver algum erro de sintaxe ou inconsistência:

1. **Inspecione os logs de erro da execução**:
   ```bash
   cat /tmp/tf_error
   ```

2. **Verifique o batch compilado para identificar a linha causadora da falha**:
   ```bash
   less /etc/tuxfrw-nft/tuxfrw.nft
   ```

3. **Valide a sintaxe diretamente através do interpretador nftables (sem aplicar)**:
   ```bash
   sudo /usr/sbin/nft -c -f /etc/tuxfrw-nft/tuxfrw.nft
   ```

4. **Acompanhe pacotes descartados pelo firewall em tempo real**:
   ```bash
   sudo journalctl -k -f | grep "tuxfrw:"
   ```
   *(Nota: Certifique-se de que as regras de log do módulo desejado estejam descomentadas).*

---

## 12. Instalação e Inicialização com Systemd

Para o guia detalhado de instalação, consulte [INSTALL.pt-br.md](../INSTALL.pt-br.md).

```bash
# Executar a instalação a partir do diretório do código-fonte
sudo ./install.sh
```

O instalador:
1. Copia o executável para `/usr/sbin/tuxfrw-nft` (`0700`);
2. Instala as configurações e módulos em `/etc/tuxfrw-nft/` (`0600`);
3. Instala a unidade `/etc/systemd/system/tuxfrw-nft.service` e executa `systemctl daemon-reload`.

> [!IMPORTANT]
> **Aviso de Segurança**: Por padrão, o instalador **NÃO** habilita o serviço no boot. Revise suas regras, inicie manualmente com `tuxfrw-nft start`, confirme seu acesso SSH e contêineres, e somente então ative a inicialização automática:
> ```bash
> sudo systemctl enable tuxfrw-nft
> ```

---

## 13. Referências e Créditos

- **Autor e Mantenedor**: Marcelo Gondim <gondim@gmail.com>
- **Repositório Oficial**: [https://github.com/gondimcodes/tuxfrw-nft](https://github.com/gondimcodes/tuxfrw-nft)
- **Documentação Oficial Netfilter / nftables**: [https://wiki.nftables.org/](https://wiki.nftables.org/)
- **Licença**: GNU General Public License v2 (GPLv2). Consulte o arquivo [LICENSE](../LICENSE).
