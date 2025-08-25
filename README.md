# BADASS – BGP At Doors of Autonomous Systems is Simple

> **Project:** BADASS (BGP At Doors of Autonomous Systems is Simple)
>
> **Summary:** This repository contains the completed project for BADASS. It is a hands‑on network-administration lab built with **GNS3** and **Docker**. The project demonstrates how to run FRRouting (FRR) instances, build VXLAN overlays (VNI=10), and use **BGP‑EVPN** (RFC 7432) with Route Reflection.

---

## Table of contents

* [Project overview](#project-overview)
* [Repository structure](#repository-structure)
* [Requirements](#requirements)
* [Part 1 – GNS3 & Docker (P1)](#part-1--gns3--docker-p1)

  * [Building Docker images](#building-docker-images)
  * [Important Dockerfile notes](#important-dockerfile-notes)
  * [GNS3 template / start command](#gns3-template--start-command)
* [Part 2 – VXLAN (P2)](#part-2--vxlan-p2)

  * [VXLAN configuration highlights](#vxlan-configuration-highlights)
  * [Verification & packet capture](#verification--packet-capture)
* [Part 3 – BGP EVPN (P3)](#part-3--bgp-evpn-p3)

  * [Topology & components](#topology--components)
  * [Route types (Type 2 vs Type 3)](#route-types-type-2-vs-type-3)
  * [How to run the P3 scripts](#how-to-run-the-p3-scripts)
  * [Verification checklist](#verification-checklist)
* [Common commands & checks](#common-commands--checks)
* [Exporting & submission](#exporting--submission)
* [Troubleshooting tips](#troubleshooting-tips)
* [License & Credits](#license--credits)

---

## Project overview

This project reproduces a small datacenter style environment in GNS3 using Docker containers:

* **P1:** Base environment (Docker images + FRR router image + BusyBox host image).
* **P2:** VXLAN (VNI 10) tests — static and dynamic/multicast modes. Learn MACs, bridging, and flood behavior.
* **P3:** BGP EVPN (RFC 7432) over an OSPF underlay; a Route Reflector (RR) is used for scale. Demonstrates Type 3 routes (IMET) on clean boot and Type 2 MAC/IP advertisements when hosts appear.

> **Important constraint from the subject:** none of the containers/hosts should have an IP configured by default. Hosts are brought up during verification to observe MAC learning and EVPN advertisements.

---

## Repository structure

```
├── P1/                # Part 1 – GNS3 + Docker
│   ├── config/        # FRR config files
│   │   ├── bgpd.conf
│   │   ├── isisd.conf
│   │   └── ospfd.conf
│   ├── P1.gns3project
│   ├── Dockerfile.host    # BusyBox / Alpine host image
│   ├── Dockerfile.router  # FRR router image
│   └── Makefile
│
├── P2/                # Part 2 – VXLAN
│   ├── P2.gns3project
│   ├── _user-1        # VXLAN gateway node (GNS3 node file)
│   ├── _user-2        # Attached host node
│   ├── static/        # static topology configs (router_1, router_2)
│   └── dynamic/       # dynamic/multicast topology configs (router_1, router_2)
│
├── P3/                # Part 3 – BGP EVPN
│   ├── P3.gns3project
│   └── configuration/ # helper scripts and node configs
│       ├── Route-Reflector.sh
│       ├── Router-2.sh
│       ├── Router-3.sh
│       ├── Router-4.sh
│       └── hosts.sh
│
└── README.md
```

> Replace `user` (or `_user-*`) with your login where required by the subject (the example used `wil`). Node filenames must remain consistent across the GNS3 project files.

---

## Requirements

* Host OS: Linux (Ubuntu recommended) or a VM running Linux (the project must be executed inside a VM per the subject).
* GNS3 (latest stable)
* Docker
* docker-compose (optional)
* jq, unzip, zip (for packaging projects)
* tcpdump (for packet capture inside containers or host)

---

## Part 1 - GNS3 & Docker (P1)

### Goal

Create two Docker images and import them into GNS3:

1. **Host image** (BusyBox or Alpine) — small image used as end-hosts for VXLAN testing.
2. **Router image** (FRRouting) — runs FRR daemons: `zebra`, `bgpd`, `ospfd`, `isisd`. Contains `vtysh` and logging under `/var/log/frr`.

### Building Docker images

From the `P1/` directory run:

```bash
# Build host image (example)
docker build -t bad-ass-host -f Dockerfile.host .

# Build router image (FRR)
docker build -t bad-ass-router -f Dockerfile.router .
```

**Note:** the FRR Dockerfile used in this project enables daemons by editing `/etc/frr/daemons` and copies the configs located under `P1/config/`.

### Makefile

The provided `Makefile` automates builds and image export. Example targets:

```makefile
build-host:
	docker build -t bad-ass-host -f Dockerfile.host .

build-router:
	docker build -t bad-ass-router -f Dockerfile.router .

push: build-host build-router
	docker save bad-ass-host bad-ass-router -o images.tar
```

Run `make build-host build-router` to build both images.

### Important Dockerfile notes

* No container should have a static IP configured by default (requirement of the subject).
* FRR image entrypoint used is `/usr/lib/frr/docker-start` which starts `watchfrr` and the daemons (`zebra`, `bgpd`, `ospfd`, `isisd`, `staticd`).
* BusyBox is included in the host image (or Alpine base) to provide `sh` and common CLI tools.

### GNS3 template / start command

When creating a Docker template in GNS3 for the FRR router, set the start command to:

```
/usr/lib/frr/docker-start
```

This launches the FRR stack automatically. For host containers, the default shell is fine.

---

## Part 2 - VXLAN (P2)

### Objective

Create a VXLAN segment (`VNI = 10`) and verify MAC learning and flood behavior in two modes:

1. **Static mode:** manually configure VTEPs and static remote endpoints.
2. **Dynamic multicast mode:** use a multicast group (example `239.1.1.1`) for BUM traffic.

### Key config items

* VXLAN device name: `vxlan10` (or any name, must match across VTEPs)
* VNI: `10`
* Bridge device: `br0` — used to attach VTEP and hosts
* Ensure physical/Ethernet interfaces of the container are attached to `br0` inside the container.

### Example commands (inside router container)

```bash
# create a bridge
ip link add name br0 type bridge
ip link set br0 up

# create vxlan device and attach to bridge (static remote example)
ip link add vxlan10 type vxlan id 10 remote 10.1.1.2 dstport 4789 dev eth0
ip link set vxlan10 up
ip link set vxlan10 master br0

# attach host interface to bridge (host is a separate container network namespace)
ip link set eth1 master br0
```

> For dynamic/multicast mode, use `group 239.1.1.1` (multicast group) instead of `remote` option.

### Verification & packet capture

* Check MAC table in each VTEP. Example (FRR + Linux bridging):

```bash
bridge fdb show
# or with bridge-utils
brctl showmacs br0
```

* Use `tcpdump` to capture VXLAN frames (on the host or inside the container):

```bash
tcpdump -i eth0 -nn -vv udp port 4789
```

* You should see encapsulated Ethernet frames and link-layer addresses. With multicast dynamic mode you will also see IGMP/Multicast traffic.

---

## Part 3 - BGP EVPN (P3)

### Topology & components

* **Route Reflector (RR):** central router that reflects BGP EVPN routes to clients (leaf VTEPs).
* **Leaf (VTEP) nodes:** run FRR and BGP EVPN; advertise MACs as Type 2 routes and IMETs as Type 3.
* **Underlay routing:** OSPF runs to provide IP reachability between VTEPs and RR (simple underlay for encapsulation transport).

**VXLAN VNI = 10** is used consistently.

### Route types recap

* **Type 2 — MAC/IP Advertisement Route:** advertises MAC addresses (and optionally associated IP addresses) learned from local hosts. Generated when a host is active; used for exact unicast delivery.
* **Type 3 — Inclusive Multicast Ethernet Tag (IMET):** advertises the VTEP multicast groups for a VNI; used to construct flood lists for BUM traffic.

**Subject requirement:** on a clean startup with no hosts, only Type 3 routes should be visible (no Type 2 routes). When a single host is brought up (with no IP), a Type 2 route becomes visible for that host. Later, assigning IP addresses and enabling all hosts leads to full reachability.

### How to run the P3 scripts

From `P3/configuration/` you have helper scripts that configure the FRR instances (these scripts were used to automate the lab during validation):

```bash
# Example: run Route Reflector script on the RR node
./Route-Reflector.sh

# Run leaf router scripts on each VTEP
./Router-2.sh
./Router-3.sh
./Router-4.sh

# hosts.sh will bring hosts up or down when run inside the proper namespace
./hosts.sh start   # or stop
```

> Ensure you run the scripts on the correct GNS3 node console or inside the container shells attached to the nodes.

### Verification checklist (P3)

1. **Boot topology with all hosts disabled.**

   * Check EVPN routes on RR and VTEPs: only Type 3 IMET routes should exist.
   * Command (in vtysh): `show bgp evpn` or `show bgp l2vpn evpn` (exact command depends on FRR version).

2. **Enable a single host without IP.**

   * Watch the VTEP learn the host MAC and advertise a Type 2 route.
   * On RR: a mirrored Type 2 route should appear.

3. **Enable other hosts and assign IPs.**

   * Confirm Type 2 routes increase for each active host.
   * Ping from one host to another to verify end‑to‑end connectivity over VXLAN.

4. **Capture packets**

   * Use `tcpdump -i eth0 -nn udp and port 4789` to observe VXLAN encapsulation.
   * Capture OSPF hellos on underlay interfaces to confirm OSPF is running: `tcpdump -i eth0 -nn proto ospf`.

5. **Final checks**

   * `vtysh` outputs: `show ip route`, `show bgp summary`, `show bgp l2vpn evpn`, `show ip ospf neighbor`, `show isis neighbor`.
   * Logs: `/var/log/frr/bgpd.log`, `/var/log/frr/ospfd.log`, `/var/log/frr/isisd.log`.

---

## Common commands & checks

**Inside router container:**

```bash
# Use vtysh (FRR unified CLI)
vtysh
# inside vtysh
show running-config
show ip route
show bgp summary
show bgp l2vpn evpn
show ip ospf neighbor
show isis neighbor
exit

# Check running FRR processes in container
ps aux | grep frr

# Check logs
tail -n 200 /var/log/frr/bgpd.log

# Linux bridge and FDB
bridge link
bridge fdb show

# tcpdump example for VXLAN packets
tcpdump -i eth0 -nn udp and port 4789
```

**Notes:** FRR often binds its control sockets to localhost (`-A 127.0.0.1`), and runs `watchfrr` which will respawn daemons if they die.

---

## Exporting & submission

* Export each GNS3 project as a **portable project** (menu File → Export portable project) which creates a ZIP file. Include generated `P*.gns3project` files and the node files.
* Add all three portable project zip files and the Docker image tar (`docker save`) or Dockerfile(s) to the repository.
* Place everything in the repository root under `P1/`, `P2/`, `P3/` as required by the subject.

Suggested structure to submit in repo root (already present):

```
P1/
P2/
P3/
README.md
images.tar (optional - saved docker images)
```

---

## Troubleshooting tips

* **`vtysh` cannot connect to daemons:** check `/usr/lib/frr/docker-start` ran and `watchfrr` is present. Inspect `ps aux` to see `zebra`, `bgpd`, etc.
* **No EVPN Type 2s appear after host up:** confirm host interface is connected to the bridge (`br0`) and traffic is seen (use `tcpdump`). Ensure the VTEP's EVPN/BGP config advertises local MACs.
* **OSPF not forming neighbors:** check MTU mismatch and ensure OSPF timers and network statements match.
* **BusyBox missing:** host image must include basic shell commands (`sh`, `ip`, `bridge`, `tcpdump`); use Alpine base if minimal.

---

## License & Credits

This project was completed as an academic assignment following the subject "Bgp At Doors of Autonomous Systems is Simple (BADASS)". The FRRouting project, GNS3, Docker, and BusyBox/Alpine are used as upstream tools.

If you reuse or adapt this lab, please credit the original authors and the BADASS subject.

---

*End of README*
