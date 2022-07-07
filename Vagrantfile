# -*- mode: ruby -*-
# vi: set ft=ruby :

['vagrant-reload'].each do |plugin|
    unless Vagrant.has_plugin?(plugin)
      raise "Vagrant plugin #{plugin} is not installed!"
    end
  end

  Vagrant.configure("2") do |config|
    config.ssh.forward_agent = true
    config.vm.box = "ubuntu/focal64"
    config.vm.provision "Initial package installation", type: "shell", inline: <<-SHELL
      sudo apt -y autoremove
      sudo apt -y dist-upgrade
      # sudo apt -y update
      # sudo apt -y upgrade
      sudo apt -y install jq bird tcpdump inetutils-traceroute net-tools tcpdump inetutils-traceroute net-tools curl libsystemd-dev
      # sudo apt -y install iproute2 tcpdump inetutils-traceroute net-tools build-essential libxtables-dev linux-headers-generic python3-pip jq bird curl libsystemd-dev apt-transport-https curl software-properties-common
      cat >/etc/multipath.conf<<'EOF'
      defaults {
        user_friendly_names yes
      }
      blacklist {
        device {
          vendor "VBOX"
          product "HARDDISK"
        }
      }
EOF
      sudo systemctl restart multipathd.service
    SHELL
    config.vm.provision "Reboot after kernel upgrade", type: "reload"
    
    config.vm.define "router" do |v|
      v.vm.network "private_network", ip: "192.168.6.100", virtualbox__intnet: "dns_user_network"
      v.vm.network "private_network", ip: "192.168.7.100", virtualbox__intnet: "dns_user_network"
      v.vm.network "private_network", ip: "192.168.30.100", virtualbox__intnet: "dns_datacenter_network", :mac=> "001122334455"
      v.vm.hostname = "router"

      v.vm.provision 'Enable forwarding and configure router', type: "shell", inline: <<-SHELL
        if ! grep -q '^net.ipv4.ip_forward' /etc/sysctl.conf; then
          echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
          sysctl -w net.ipv4.ip_forward=1
        fi
        /vagrant/script/configure-vagrant-router.sh
      SHELL
    end

    def define_user(config, name, ipv4_addr)
      config.vm.define name do |v|
        v.vm.hostname = name
        v.vm.network "private_network", ip: ipv4_addr, virtualbox__intnet: "dns_user_network"
        v.vm.provider "virtualbox" do |vb|
          vb.cpus = 1
          vb.memory = "512"
        end
        v.vm.provision "Bring up demo client IPs", type: "shell", inline: <<-SHELL
          /vagrant/script/configure-vagrant-user.sh "#{ipv4_addr}"
        SHELL
    end
  end

    def define_dnsdist(config, name, ipv4_addr, ip_mgmt)
      config.vm.define name do |v|
        v.vm.hostname = name
          v.vm.network "private_network", ip: ipv4_addr, virtualbox__intnet: "dns_datacenter_network"
          v.vm.network :private_network, ip: ip_mgmt
          v.vm.provider "virtualbox" do |vb|
          vb.cpus = 1
          vb.memory = "512"
          v.vm.synced_folder "config/dnsdist/", "/etc/dnsdist", disabled: false
        end
        v.vm.provision "Configure mounts and sysctls", type: "shell", run: "always", inline: <<-SHELL
          echo "net.ipv4.conf.all.arp_filter=1" | sudo tee -a /etc/sysctl.conf
          echo "deb [arch=amd64] http://repo.powerdns.com/ubuntu focal-dnsdist-17 main" | sudo tee /etc/apt/sources.list.d/pdns.list
          echo "Package: dnsdist*" | sudo tee -a /etc/apt/preferences.d/dnsdist
          echo "Pin: origin repo.powerdns.com" | sudo tee -a /etc/apt/preferences.d/dnsdist
          echo "Pin-Priority: 600" | sudo tee -a /etc/apt/preferences.d/dnsdist
          curl https://repo.powerdns.com/FD380FBB-pub.asc | sudo apt-key add -
          sudo apt-get update
          sudo apt-get install -y dnsdist
          /vagrant/script/configure-vagrant-dnsdist.sh "#{ipv4_addr}"
        SHELL
    end

    def define_pdns(config, name, ipv4_addr, ip_mgmt)
      config.vm.define name do |v|
        v.vm.hostname = name
        v.vm.network "private_network", ip: ipv4_addr, virtualbox__intnet: "dns_datacenter_network"
        v.vm.network :private_network, ip: ip_mgmt
        v.vm.synced_folder "config/pdns/", "/etc/powerdns", disabled: false


        v.vm.provision "Set up proxy nginx demo", type: "shell", inline: <<-SHELL
          sudo systemctl disable systemd-resolved
          sudo systemctl stop systemd-resolved
          sudo unlink /etc/resolv.conf
          echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
          echo "deb [arch=amd64] http://repo.powerdns.com/ubuntu focal-auth-46 main" | sudo tee /etc/apt/sources.list.d/pdns.list
          echo "Package: pdns-*" | sudo tee -a /etc/apt/preferences.d/pdns
          echo "Pin: origin repo.powerdns.com" | sudo tee -a /etc/apt/preferences.d/pdns
          echo "Pin-Priority: 600" | sudo tee -a /etc/apt/preferences.d/pdns
          curl https://repo.powerdns.com/FD380FBB-pub.asc | sudo apt-key add -
          sudo apt-get update
          sudo apt-get install -y pdns-server pdns-backend-sqlite3 sqlite3
          /vagrant/script/configure-vagrant-pdns.sh "#{ipv4_addr}"
        SHELL
      end
    end
  end
  define_user config, "user1",     "192.168.6.6"
  define_user config, "user2",     "192.168.7.7"
  define_dnsdist config, "dnsdist1",     "192.168.30.2",  "192.168.100.2"
  define_dnsdist config, "dnsdist2",     "192.168.30.3",  "192.168.100.3"
  define_pdns    config,    "pdns1",     "192.168.30.10", "192.168.100.11"
  define_pdns    config,    "pdns2",     "192.168.30.11", "192.168.100.12"
end