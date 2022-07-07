local_ipv4_ip="$1"

# sudo mkdir /var/lib/powerdns
sudo sqlite3 /var/lib/powerdns/pdns.sqlite3 < /usr/share/doc/pdns-backend-sqlite3/schema.sqlite3.sql
sudo chown -R pdns:pdns /var/lib/powerdns


cat >/etc/powerdns/pdns.conf <<EOF
api=yes
api-key=changeme
include-dir=/etc/powerdns/pdns.d
launch=gsqlite3
gsqlite3-database=/var/lib/powerdns/pdns.sqlite3
security-poll-suffix=
webserver=yes
webserver-address=0.0.0.0
webserver-allow-from=0.0.0.0/0
edns-subnet-processing=yes
EOF

# sudo chown -R pdns:pdns /etc/powerdns/pdns.conf
chmod +r /etc/powerdns/pdns.conf

sudo systemctl enable pdns
sudo systemctl restart pdns

sudo -u root pdnsutil create-zone example.com ns1.example.com
sudo -u root pdnsutil add-record example.com '' MX '25 mail.example.com'
sudo -u root pdnsutil add-record example.com. www A ${local_ipv4_ip}
