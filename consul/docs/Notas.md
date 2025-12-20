Service discovery.


Network traffic ports
All communication happens over http and https
Network communication protected by TLS and gossip key

Posrts:
- HTTP API: 8500 (TCP): This is for HTTP API communication with Consul agents
- DNS Interface: 8600 (TCP/UDP): This is for DNS queries to services registered with Consul
- LAN Gossip: 8301 (TCP/UDP): This is for communication between agents in the same datacenter
- WAN Gossip: 8302 (TCP/UDP): This is for datacenter to datacenter communication
- RPC: 8400 (TCP): This is for internal RPC communication between Consul agents
- Sidecar proxy: 20000-21250 (TCP): This is for communication between sidecar proxies and services