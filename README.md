# docker-keepalived-for-kubernetes

## Environment variables

- `VRRP_PASS` (no default, mandatory): VRRP password
- `VRRP_PEER_GROUPS` (no default, mandatory): nodes IPs used to setup VRRP (see below)
- `CHK_PROTO` (default: `https`): health check proto on Ingress Controller (no TLS check)
- `CHK_PORT` (default: `443`): Ingress Controller's main port used for health check and listening IPs detection
- `CHK_URI` (default: `/healthz`): health check URI on Ingress Controller

## VRRP peer groups

Delimiters:
- `|`: group delimiter
- ` `: IPs/CIDR delimiter in VRRP groups
- `;`: VIPs (CIDR) delimiter in VRRP group
- `,`: default gateway to link to VIPs in VRRP group

Example:
```
VRRP_PEER_GROUPS=172.31.226.108 172.31.226.109 172.31.226.110|10.34.0.11 10.34.0.12 10.34.0.10;10.34.0.1/24 10.34.0.2/24,10.34.0.254|10.34.1.10 10.34.1.11 10.34.1.12;10.34.1.1/24 10.34.1.2/24,10.34.1.254
```
Will configure 1 VRRP group containing 3 VRRP instances (`172.31.226.*`, `10.34.0.*` and `10.34.1.*`), as long as nodes contain IPs declared in the group, each group with its VIPs and gateway (here 2 VIPs `10.34.1.1/24` and `10.34.1.2/24` and 1 gateway `10.34.1.254` in the instance `10.34.1.*`)

