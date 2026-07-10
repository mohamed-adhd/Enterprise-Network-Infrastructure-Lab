<div align="center">

# Enterprise Network Infrastructure Lab

<p>
  <b>A GNS3 enterprise routing lab built around FRR, OSPFv2, GRE overlays, IPsec transport protection, multi-LAN site routing, and VPCS endpoint validation.</b>
</p>

<p>
  <img alt="GNS3" src="https://img.shields.io/badge/GNS3-Network%20Emulation-2f80ed?style=for-the-badge">
  <img alt="OSPFv2" src="https://img.shields.io/badge/OSPFv2-Area%200-ff6b35?style=for-the-badge">
  <img alt="FRRouting" src="https://img.shields.io/badge/FRRouting-FRR%208.4-00a86b?style=for-the-badge">
  <img alt="GRE" src="https://img.shields.io/badge/GRE-Overlay%20Tunnel-7c3aed?style=for-the-badge">
  <img alt="IPsec" src="https://img.shields.io/badge/IPsec-XFRM%20Transport-d90429?style=for-the-badge">
</p>

<p>
  <img alt="Linux" src="https://img.shields.io/badge/Linux-Routing%20Stack-fcc624?style=flat-square&logo=linux&logoColor=black">
  <img alt="Docker" src="https://img.shields.io/badge/Docker-Router%20Nodes-2496ed?style=flat-square&logo=docker&logoColor=white">
  <img alt="VPCS" src="https://img.shields.io/badge/VPCS-Endpoint%20Testing-38bdf8?style=flat-square">
  <img alt="Static XFRM" src="https://img.shields.io/badge/XFRM-Manual%20SA%20Policy-ef4444?style=flat-square">
  <img alt="Routing Lab" src="https://img.shields.io/badge/Focus-Enterprise%20WAN%20Design-111827?style=flat-square">
</p>

<p>
  <a href="#network-design"><img alt="Network Design" src="https://img.shields.io/badge/Network-Design-00d084?style=for-the-badge"></a>
  <a href="#routing-core"><img alt="Routing Core" src="https://img.shields.io/badge/Routing-Core-f97316?style=for-the-badge"></a>
  <a href="#verification"><img alt="Verification" src="https://img.shields.io/badge/Verification-Commands-24c8db?style=for-the-badge"></a>
  <a href="#why-i-built-this"><img alt="Why I Built This" src="https://img.shields.io/badge/Why-I%20Built%20This-8b5cf6?style=for-the-badge"></a>
</p>

</div>

---

## Overview

**Enterprise Network Infrastructure Lab** is a realistic two-site routing topology built in GNS3. It models how separated LANs can be connected through routed Linux/FRR nodes, advertised with **OSPFv2**, and extended through a **GRE overlay** that can be protected with Linux **XFRM/IPsec transport mode**.

This is not a toy static-routing diagram. The repository contains actual GNS3 project files, FRRouting configuration, VPCS startup configs, GRE environment files, IPsec setup scripts, and saved router state from the lab.

## Network Design

The topology is centered on two FRR router containers:

| Site | Router | Router ID | LAN networks | Transit / overlay |
| --- | --- | --- | --- | --- |
| Site 1 | `site1-router` | `1.1.1.1` | `192.168.1.0/24`, `192.168.2.0/24` | `10.0.0.1/30`, `10.0.1.1/30`, `172.16.0.1/30` |
| Site 2 | `site2-router` | `2.2.2.2` | `192.168.3.0/24`, `192.168.4.0/24` | `10.0.0.2/30`, `10.0.1.2/30`, `172.16.0.2/30` |

The active GNS3 project, `ospf-v2.gns3`, defines:

| Layer | Nodes |
| --- | --- |
| Routing | `site1-router`, `site2-router` |
| Switching | `Switch1`, `Switch2`, `Switch3`, `Switch4` |
| Endpoints | `pc1.1`, `pc1.2`, `pc2`, `pc3.1`, `pc3.2`, `pc4` |

## Addressing Plan

| Segment | Gateway / router interface | Endpoint examples |
| --- | --- | --- |
| Site 1 LAN A | `192.168.1.1/24` | `pc1.1: 192.168.1.11`, `pc1.2: 192.168.1.12` |
| Site 1 LAN B | `192.168.2.1/24` | `pc2: 192.168.2.11` |
| Site 2 LAN A | `192.168.3.1/24` | `pc4: 192.168.3.11` |
| Site 2 LAN B | `192.168.4.1/24` | `pc3.1: 192.168.4.11`, `pc3.2: 192.168.4.12` |
| Direct underlay | `10.0.0.1/30` to `10.0.0.2/30` | Router-to-router transit |
| Protected underlay | `10.0.1.1/30` to `10.0.1.2/30` | GRE/IPsec transport path |
| GRE overlay | `172.16.0.1/30` to `172.16.0.2/30` | OSPF adjacency over tunnel |

## Routing Core

The lab uses **OSPF area 0** as the routing backbone between the two sites. Each router advertises its local LANs and the GRE tunnel network.

### `site1-router`

```frr
router ospf
 ospf router-id 1.1.1.1
 network 172.16.0.0/30 area 0
 network 192.168.1.0/24 area 0
 network 192.168.2.0/24 area 0
```

### `site2-router`

```frr
router ospf
 ospf router-id 2.2.2.2
 network 172.16.0.0/30 area 0
 network 192.168.3.0/24 area 0
 network 192.168.4.0/24 area 0
```

The GRE interface is treated as a point-to-point routing link:

```frr
interface gre1
 ip address 172.16.0.2/30
 ip ospf network point-to-point
```

## GRE Overlay

The project keeps GRE parameters in router-local environment files:

| Router | GRE interface | Local underlay | Remote underlay | GRE address |
| --- | --- | --- | --- | --- |
| `site1-router` | `gre1` | `10.0.1.1` | `10.0.1.2` | `172.16.0.1/30` |
| `site2-router` | `gre1` | `10.0.1.2` | `10.0.1.1` | `172.16.0.2/30` |

That design keeps the overlay separate from the LANs and lets OSPF exchange routes over a clean routed tunnel instead of relying only on the physical GNS3 links.

## IPsec / XFRM Layer

The repository includes a Linux XFRM setup script for protecting GRE traffic between the router underlay addresses. The script:

| Step | Purpose |
| --- | --- |
| Removes old XFRM policies and states | Keeps repeated lab runs clean |
| Adds ESP transport-mode states | Protects GRE protocol `47` between routers |
| Adds directional policies | Applies protection to outbound and inbound GRE |
| Uses router-local `GRE_LOCAL` | Chooses the correct policy direction per router |

The result is a lab-grade model of a common enterprise pattern:

```text
LAN routes -> OSPF -> GRE tunnel -> IPsec transport protection -> remote site
```

## Repository Layout

```text
Enterprise-Network-Infrastructure-Lab/
├── README.md
├── ospf-v2.gns3
├── project-files/
│   ├── docker/
│   │   └── <router-id>/etc/frr/
│   │       ├── frr.conf
│   │       ├── ospfd.conf
│   │       ├── zebra.conf
│   │       ├── gre.env
│   │       ├── ipsec.env
│   │       └── setup-ipsec.sh
│   └── vpcs/
│       └── <pc-id>/startup.vpc
└── c1d1919f-1120-44aa-925c-880c0e27a8be/
    └── archived GNS3 project state and earlier backups
```

## Key Files

| File | Why it matters |
| --- | --- |
| `ospf-v2.gns3` | Main GNS3 topology definition |
| `project-files/docker/.../etc/frr/frr.conf` | Integrated FRR router configuration |
| `project-files/docker/.../etc/frr/ospfd.conf` | OSPF daemon-specific routing config |
| `project-files/docker/.../etc/frr/zebra.conf` | Interface addressing and zebra config |
| `project-files/docker/.../etc/frr/gre.env` | GRE tunnel variables |
| `project-files/docker/.../etc/frr/setup-ipsec.sh` | Linux XFRM/IPsec policy setup |
| `project-files/vpcs/.../startup.vpc` | Endpoint addressing and default gateways |

## Verification

Inside the FRR router nodes:

```bash
vtysh
show ip ospf neighbor
show ip route ospf
show running-config
```

Inside the Linux router shell:

```bash
ip addr show
ip tunnel show
ip xfrm state
ip xfrm policy
```

From VPCS endpoints:

```bash
ping 192.168.3.11
ping 192.168.4.11
trace 192.168.4.12
```

Expected behavior: endpoints behind Site 1 should be able to reach endpoints behind Site 2 after the routers form OSPF adjacency over the GRE path and learn the remote LAN prefixes.

## What This Lab Proves

| Concept | Evidence in the repo |
| --- | --- |
| Multi-site routing | Separate LANs on both routers with VPCS clients behind switches |
| Dynamic routing | FRR OSPF area 0 configs with router IDs and advertised prefixes |
| Overlay networking | GRE `gre1` tunnel addressing on `172.16.0.0/30` |
| Secure transport model | XFRM policies protecting GRE between underlay router IPs |
| Endpoint validation | VPCS startup configs with real IPs and gateways |
| GNS3 reproducibility | Saved `.gns3` topology plus `project-files` state |

## Why I Built This

> at some point of my carrer i will have to get in contact with networking , wether it was backend developement, network automatation , or embedded system , so i wanted to catch a glance at it . well i catched more than a glance , but still it was a fun repo
```

---

<div align="center">
  <sub>Built with GNS3, FRRouting, OSPFv2, GRE, Linux XFRM/IPsec, Docker router nodes, and VPCS endpoints.</sub>
</div>
