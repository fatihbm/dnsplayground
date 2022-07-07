#!/bin/bash -e


local_ipv4_ip="$1"
last_octet="${local_ipv4_ip#*.*.*.}"

## BIRD

cat >/etc/bird/bird.conf <<EOF
filter anycastdns {
  # the example IPv4 VIP announced by GLB
  if net = 10.10.10.10/32 then accept;
}

router id ${local_ipv4_ip};

protocol direct {
  interface "lo"; # Restrict network interfaces BIRD works with
}

protocol kernel {
  persist; # Don't remove routes on bird shutdown
  scan time 20; # Scan kernel routing table every 20 seconds
  import all; # Default is import all
  export all; # Default is export none
}

# This pseudo-protocol watches all interface up/down events.
protocol device {
  scan time 10; # Scan interfaces every 10 seconds
}

protocol bgp {
  local as 6500${last_octet};

  import none;
  export filter anycastdns;

  neighbor 192.168.30.100 as 65302;
}

protocol static {
  route 10.10.10.10/32 via ${local_ipv4_ip};
}
EOF

systemctl restart bird

cat >/etc/dnsdist/dnsdist.conf <<EOF
webserver("0.0.0.0:8083")
setWebserverConfig({password="pass", apiKey="key", acl="0.0.0.0/0"})
controlSocket('127.0.0.1:5199')
setKey("9XYRs43uE1vwpI3mF00Fq4a5JjFICIccCwC1/pZRe+U=")

setSecurityPollSuffix("")
setLocal("10.10.10.10:53")
addACL("0.0.0.0/0")

newServer{address="192.168.30.10", name="PDNS1", order=1, weight=1000, pool='auth'}
newServer{address="192.168.30.11", name="PDNS2", order=1, weight=1000, pool='auth'}
newServer{address="8.8.8.8", name="G V4 Pri", order=3, weight=1, pool='recursor'}
newServer{address="8.8.4.4", name="G V4 Sec", order=3, weight=1, pool='recursor'}

addAction({"example.com.", "xxx."}, PoolAction("auth"))
addAction(AllRule(), PoolAction('recursor'))

pc = newPacketCache(10000, --- create a new pool cache "pc" with 10.000 entries
 {
 maxTTL=86400, --- maximum TTL cache time
 minTTL=10, --- minimum TTL cache time
 temporaryFailureTTL=60, --- TTL used for server failures or "refused"
 staleTTL=60, --- TTL for stale cache entries
 dontAge=false --- cache entries "age", their TTL is decremented in cache
})
getPool("*"):setCache(pc) --- assign the cache to the default pool
EOF


cat >/etc/netplan/50-vagrant.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      addresses:
      - ${local_ipv4_ip}/24
      routes:
      - to: 192.168.6.0/24
        via: 192.168.30.100
      - to: 192.168.7.0/24
        via: 192.168.30.100
    lo:
      addresses:
      - 10.10.10.10/32
    enp0s9:
      addresses:
      - ${ip_mgmt}/24
EOF

netplan apply
systemctl enable dnsdist
systemctl restart dnsdist
