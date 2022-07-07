#!/bin/bash -e

local_ipv4_ip="$1"
last_octet="${local_ipv4_ip#*.*.*.}"

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

  import filter anycastdns;
  export none;

  # user side neighbor
  neighbor 192.168.${last_octet}.100 as 640${last_octet}3;
}
EOF


cat >/etc/netplan/50-vagrant.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      addresses:
      - ${local_ipv4_ip}/24
      - 192.168.${last_octet}.50/24
      - 192.168.${last_octet}.51/24
      - 192.168.${last_octet}.52/24
      - 192.168.${last_octet}.53/24
      - 192.168.${last_octet}.54/24
      - 192.168.${last_octet}.55/24
EOF

netplan apply
systemctl restart bird