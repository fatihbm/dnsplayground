#!/bin/bash -e

cat >/etc/bird/bird.conf <<EOF
filter anycastdns {
  # the example IPv4 VIP announced by GLB
  if net = 10.10.10.10/32 then accept;
}

router id 192.168.30.100;

protocol direct {
  interface "lo"; # Restrict network interfaces BIRD works with
}

protocol kernel {
  persist; # Don't remove routes on bird shutdown
  scan time 20; # Scan kernel routing table every 20 seconds
  import all; # Default is import all
  export all; # Default is export none
  merge paths on;
}

# This pseudo-protocol watches all interface up/down events.
protocol device {
  scan time 10; # Scan interfaces every 10 seconds
}

protocol bgp users1 {
  local as 64063;

  import none;
  export filter anycastdns;

  neighbor 192.168.6.6 as 65006;
}

protocol bgp users2 {
  local as 64073;

  import none;
  export filter anycastdns;

  neighbor 192.168.7.7 as 65007;
}

protocol bgp dnsdist1 {
  local as 65302;

  import filter anycastdns;
  export none;

  neighbor 192.168.30.2 as 65002;
}

protocol bgp dnsdist2 {
  local as 65302;

  import filter anycastdns;
  export none;

  neighbor 192.168.30.3 as 65003;
}
EOF

systemctl restart bird