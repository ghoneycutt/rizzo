# This file generated with Rizzo 0.1.0 on 2017-08-18 13:00:09 -0700
# https://github.com/ghoneycutt/rizzo
Vagrant.configure(2) do |config|
  # use 'vagrant plugin install vagrant-proxyconf' to install
  if Vagrant.has_plugin?('vagrant-proxyconf')
    config.proxy.http  = ENV['HTTP_PROXY']  if ENV['HTTP_PROXY']
    config.proxy.https = ENV['HTTPS_PROXY'] if ENV['HTTPS_PROXY']
  end

  config.vm.define "puppetca", autostart: false do |cfg|
    cfg.vm.box = "el6-rc5"
    cfg.vm.box_url = "https://artifactory.acme.net/artifactory/infra-vagrant-local/centos-6-x86-64-acme-2017-06-14t13-27-20-0400.box"
    cfg.vm.box_download_checksum = "37f67caf1038992207555513504e37258c29e2e9"
    cfg.vm.box_download_checksum_type = "sha1"
    cfg.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', "2048"]
    end
    cfg.vm.hostname = "puppetca.acme.com"
    cfg.vm.network 'private_network',
      ip: "172.16.100.5",
      netmask: "255.255.255.0"
    cfg.vm.network 'forwarded_port',
      guest: "8140",
      host: "8140"
    cfg.vm.synced_folder "/Users/jeff/projects/acme/puppetdata", "/repos/puppetdata",
      owner: "root", group: "root"
    cfg.vm.synced_folder "/Users/jeff/projects/acme/ghoneycutt-modules", "/repos/ghoneycutt",
      owner: "root", group: "root"
    cfg.vm.synced_folder "/Users/jeff/projects/acme/bootstrap",
      "/tmp/bootstrap_puppet4",
      owner: 'vagrant', group: 'root'
    cfg.vm.provision 'shell', inline: "echo 'modulepath = ./modules:./puppetdata/modules:./ghoneycutt/modules' > /tmp/bootstrap_puppet4/environment.conf"
    cfg.vm.provision 'shell', inline: "/bin/bash /tmp/bootstrap_puppet4/bootstrap_puppet4.sh -l -f `hostname -f`"
    cfg.vm.provision 'shell', inline: "yum -y update"
    cfg.vm.provision 'shell', inline: "/sbin/shutdown -h now"
  end

  config.vm.define "puppet", autostart: false do |cfg|
    cfg.vm.box = "el6-rc5"
    cfg.vm.box_url = "https://artifactory.acme.net/artifactory/infra-vagrant-local/centos-6-x86-64-acme-2017-06-14t13-27-20-0400.box"
    cfg.vm.box_download_checksum = "37f67caf1038992207555513504e37258c29e2e9"
    cfg.vm.box_download_checksum_type = "sha1"
    cfg.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', "2048"]
    end
    cfg.vm.hostname = "puppet.acme.com"
    cfg.vm.network 'private_network',
      ip: "172.16.100.6",
      netmask: "255.255.255.0"
    cfg.vm.synced_folder "/Users/jeff/projects/acme/puppetdata", "/repos/puppetdata",
      owner: "root", group: "root"
    cfg.vm.synced_folder "/Users/jeff/projects/acme/ghoneycutt-modules", "/repos/ghoneycutt",
      owner: "root", group: "root"
    cfg.vm.synced_folder "/Users/jeff/projects/acme/bootstrap",
      "/tmp/bootstrap_puppet4",
      owner: 'vagrant', group: 'root'
    cfg.vm.provision 'shell', inline: "echo 'modulepath = ./modules:./puppetdata/modules:./ghoneycutt/modules' > /tmp/bootstrap_puppet4/environment.conf"
    cfg.vm.provision 'shell', inline: "/bin/bash /tmp/bootstrap_puppet4/bootstrap_puppet4.sh -l -f `hostname -f`"
    cfg.vm.provision 'shell', inline: "yum -y update"
    cfg.vm.provision 'shell', inline: "/sbin/shutdown -h now"
  end

  config.vm.define "dns", autostart: false do |cfg|
    cfg.vm.box = "el6-rc5"
    cfg.vm.box_url = "https://artifactory.acme.net/artifactory/infra-vagrant-local/centos-6-x86-64-acme-2017-06-14t13-27-20-0400.box"
    cfg.vm.box_download_checksum = "37f67caf1038992207555513504e37258c29e2e9"
    cfg.vm.box_download_checksum_type = "sha1"
    cfg.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', "1024"]
    end
    cfg.vm.hostname = "dns.acme.com"
    cfg.vm.network 'private_network',
      ip: "172.16.100.8",
      netmask: "255.255.255.0"
    cfg.vm.synced_folder "/Users/jeff/projects/acme/bootstrap",
      "/tmp/bootstrap_puppet4",
      owner: 'vagrant', group: 'root'
    cfg.vm.provision 'shell', inline: "/bin/bash /tmp/bootstrap_puppet4/bootstrap_puppet4.sh -l -f `hostname -f`"
    cfg.vm.provision 'shell', inline: "yum -y update"
    cfg.vm.provision 'shell', inline: "/sbin/shutdown -h now"
  end

  config.vm.define "logs", autostart: false do |cfg|
    cfg.vm.box = "el6-rc5"
    cfg.vm.box_url = "https://artifactory.acme.net/artifactory/infra-vagrant-local/centos-6-x86-64-acme-2017-06-14t13-27-20-0400.box"
    cfg.vm.box_download_checksum = "37f67caf1038992207555513504e37258c29e2e9"
    cfg.vm.box_download_checksum_type = "sha1"
    cfg.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', "1024"]
    end
    cfg.vm.hostname = "logs.acme.com"
    cfg.vm.network 'private_network',
      ip: "172.16.100.12",
      netmask: "255.255.255.0"
    cfg.vm.synced_folder "/Users/jeff/projects/acme/bootstrap",
      "/tmp/bootstrap_puppet4",
      owner: 'vagrant', group: 'root'
    cfg.vm.provision 'shell', inline: "/bin/bash /tmp/bootstrap_puppet4/bootstrap_puppet4.sh -l -f `hostname -f`"
    cfg.vm.provision 'shell', inline: "yum -y update"
    cfg.vm.provision 'shell', inline: "/sbin/shutdown -h now"
  end

  config.vm.define "mail", autostart: false do |cfg|
    cfg.vm.box = "el6-rc5"
    cfg.vm.box_url = "https://artifactory.acme.net/artifactory/infra-vagrant-local/centos-6-x86-64-acme-2017-06-14t13-27-20-0400.box"
    cfg.vm.box_download_checksum = "37f67caf1038992207555513504e37258c29e2e9"
    cfg.vm.box_download_checksum_type = "sha1"
    cfg.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', "1024"]
    end
    cfg.vm.hostname = "mail.acme.com"
    cfg.vm.network 'private_network',
      ip: "172.16.100.13",
      netmask: "255.255.255.0"
    cfg.vm.synced_folder "/Users/jeff/projects/acme/bootstrap",
      "/tmp/bootstrap_puppet4",
      owner: 'vagrant', group: 'root'
    cfg.vm.provision 'shell', inline: "/bin/bash /tmp/bootstrap_puppet4/bootstrap_puppet4.sh -l -f `hostname -f`"
    cfg.vm.provision 'shell', inline: "yum -y update"
    cfg.vm.provision 'shell', inline: "/sbin/shutdown -h now"
  end

  config.vm.define "jumpbox", autostart: false do |cfg|
    cfg.vm.box = "el6-rc5"
    cfg.vm.box_url = "https://artifactory.acme.net/artifactory/infra-vagrant-local/centos-6-x86-64-acme-2017-06-14t13-27-20-0400.box"
    cfg.vm.box_download_checksum = "37f67caf1038992207555513504e37258c29e2e9"
    cfg.vm.box_download_checksum_type = "sha1"
    cfg.vm.boot_timeout = 300
    cfg.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', "1024"]
    end
    cfg.vm.hostname = "jumpbox.acme.com"
    cfg.vm.network 'private_network',
      ip: "172.16.100.26",
      netmask: "255.255.255.0"
    cfg.vm.synced_folder "/Users/jeff/projects/acme/bootstrap",
      "/tmp/bootstrap_puppet4",
      owner: 'vagrant', group: 'root'
    cfg.vm.provision 'shell', inline: "/bin/bash /tmp/bootstrap_puppet4/bootstrap_puppet4.sh -l -f `hostname -f`"
    cfg.vm.provision 'shell', inline: "yum -y update"
    cfg.vm.provision 'shell', inline: "/sbin/shutdown -h now"
  end

  config.vm.define "windows", autostart: false do |cfg|
    cfg.vm.box = "win2016"
    cfg.vm.box_url = "https://artifactory.acme.net/artifactory/infra-vagrant-local/windows2016.box"
    cfg.vm.box_download_checksum = "123456781038992207555513504e37258c29e2e9"
    cfg.vm.box_download_checksum_type = "sha1"
    cfg.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', "1024"]
      vb.gui = true
    end
    cfg.vm.guest = :windows
    cfg.vm.communicator = :winrm
    cfg.vm.hostname = "windows"
    cfg.vm.network 'private_network',
      ip: "172.16.100.27",
      netmask: "255.255.255.0"
    cfg.vm.network 'forwarded_port',
      guest: "5985",
      host: "5985"
    cfg.vm.synced_folder "/Users/jeff/projects/acme/bootstrap_windows",
      "C:\\tmp\\bootstrap_puppet4",
      owner: 'vagrant', group: 'root'
    cfg.vm.provision 'shell', inline: "C:\\tmp\\bootstrap_puppet4\\bootstrap_puppet4.ps1 "
  end

  config.vm.define "windows2", autostart: false do |cfg|
    cfg.vm.box = "win2016"
    cfg.vm.box_url = "https://artifactory.acme.net/artifactory/infra-vagrant-local/windows2016.box"
    cfg.vm.box_download_checksum = "123456781038992207555513504e37258c29e2e9"
    cfg.vm.box_download_checksum_type = "sha1"
    cfg.vm.provider :virtualbox do |vb|
      vb.customize ['modifyvm', :id, '--memory', "1024"]
    end
    cfg.vm.guest = :windows
    cfg.vm.communicator = :winrm
    cfg.vm.hostname = "windows2"
    cfg.vm.network 'private_network',
      ip: "172.16.100.28",
      netmask: "255.255.255.0"
    cfg.vm.network 'forwarded_port',
      guest: "15985",
      host: "15985"
    cfg.vm.synced_folder "/Users/jeff/projects/acme/bootstrap_windows",
      "C:\\tmp\\bootstrap_puppet4",
      owner: 'vagrant', group: 'root'
    cfg.vm.provision 'shell', inline: "C:\\tmp\\bootstrap_puppet4\\bootstrap_puppet4.ps1 arg1 arg2"
  end
end
# -*- mode: ruby -*-
# vim:ft=ruby
