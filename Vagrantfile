# -*- mode: ruby -*-
# vim: set ft=ruby :

require 'erb'
require 'deep_merge'
require 'json'
require 'pp'

DEFAULT_NO_PROXY = 'localhost,127.0.0.1'.freeze
VAGRANTFILE_API_VERSION = '2'.freeze

# Allow for debugging by setting environment variable RIZZO_DEBUG=true
debug = true if ENV['RIZZO_DEBUG'] == 'true'

puts "RIZZO_DEBUG = #{debug}" if debug

# Read project rizzo configuration by looping through control repos and
# stopping at first match and merge on top of local, defaults (~/.rizzo.json)
if File.readable?("#{Dir.home}/.rizzo.json")
  puts "\n\n#{Dir.home}/.rizzo.json found" if debug
  dconfig_json = File.read("#{Dir.home}/.rizzo.json")
  dconfig = JSON.parse(dconfig_json)
else
  puts "\n\n#{Dir.home}/.rizzo.json NOT found"
  exit 1
end
i = 0
while i < dconfig['control_repos'].length
  if File.readable?("#{dconfig['control_repos'][i]}/.rizzo.json")
    pconfig_json = File.read("#{dconfig['control_repos'][i]}/.rizzo.json")
    pconfig = JSON.parse(pconfig_json)
    rconfig = pconfig.deep_merge(dconfig)
    break
  end
  i += 1
end
unless pconfig
  puts 'no .rizzo.json found in any control repo'
  exit 1
end

puts 'rconfig' if debug
puts JSON.pretty_generate(rconfig) if debug

# Check for duplicate ports and IP addresses across all hosts and exit non-zero
# with an error message if found.
host_ports = []
ips = []
rconfig['nodes'].each do |node|
  if node.key?('forwarded_ports') && !node['forwarded_ports'].empty?
    node['forwarded_ports'].each do |forwarded_port|
      port = forwarded_port['host'].to_i
      if host_ports.include?(port) == true
        puts "host port #{port} on node #{node['name']} is a duplicate and must be unique."
        exit 1
      else
        host_ports << port
      end
    end
  end

  if ips.include?(node['ip']) == true
    puts "IP address #{node['ip']} on node #{node['name']} is a duplicate and must be unique."
    exit 1
  else
    ips << node['ip']
  end
end

puts "\n\nhost_ports = #{host_ports}\nips = #{ips}" if debug

pm_settings = rconfig['puppetmaster']
puts "\n\nrconfig['puppetmaster']" if debug
pp pm_settings if debug

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # use 'vagrant plugin install vagrant-proxyconf' to install
  if Vagrant.has_plugin?('vagrant-proxyconf')
    config.proxy.http = ENV['HTTP_PROXY'] if ENV.key?('HTTP_PROXY')
    config.proxy.https = ENV['HTTPS_PROXY'] if ENV.key?('HTTPS_PROXY')
    # use Rizzo's config if it exists, else use the default.
    config.proxy.no_proxy = if rconfig.key?('config') && rconfig['config'].key?('no_proxy') && !rconfig['config']['no_proxy'].empty?
                              rconfig['config']['no_proxy']
                            else
                              DEFAULT_NO_PROXY
                            end
  end

  rconfig['nodes'].each do |node|
    if node['name'] == pm_settings['name']
      n = node.deep_merge(pm_settings)
      puppetmaster = true
    else
      n = node
      puppetmaster = false
    end
    nc = n.deep_merge(rconfig['defaults'])

    puts "\npuppetmaster is #{puppetmaster} on #{node['name']}" if debug
    puts "\n\nnode config - node deep merged with rconfig['defaults']" if debug
    pp nc if debug

    config.vm.define nc['name'], autostart: false do |config|
      config.vm.box = nc['box']
      config.vm.box_url = nc['box_url']
      config.vm.box_download_checksum = nc['box_download_checksum']
      config.vm.box_download_checksum_type = nc['box_download_checksum_type']
      config.vm.provider :virtualbox do |vb|
        vb.customize ['modifyvm', :id, '--memory', nc['memory']]
      end
      config.vm.hostname = nc['hostname']
      config.vm.network 'private_network',
                        ip: nc['ip'],
                        netmask: nc['netmask']
      if nc.key?('forwarded_ports') && !nc['forwarded_ports'].empty?
        nc['forwarded_ports'].each do |forwarded_port|
          config.vm.network 'forwarded_port',
                            guest: forwarded_port['guest'],
                            host: forwarded_port['host']
        end
      end
      if nc.key?('synced_folders') && !nc['synced_folders'].empty?
        nc['synced_folders'].each do |k, v|
          config.vm.synced_folder v['local'], k,
                                  owner: v['owner'], group: v['group']
        end
      end
      if nc['bootstrap_repo_path']
        puts "\n#{nc['name']}: Using provisioner for bootstrap" if debug
        config.vm.synced_folder nc['bootstrap_repo_path'], nc['bootstrap_guest_path'],
                                owner: 'vagrant', group: 'root'
        if puppetmaster == true
          # create environment.conf from template
          if File.readable?('environment.conf.erb')
            template = ERB.new File.read('environment.conf.erb')
            envconf = template.result(binding)
            File.open('environment.conf', 'w') do |f|
              f.write envconf
            end
            config.vm.provision 'file', source: 'environment.conf', destination: "#{nc['bootstrap_guest_path']}/environment.conf"
          else
            puts 'environment.conf.erb is missing or not readable.'
            exit 1
          end
        end
        puts "\nnc['name']: shell provisioner - inline = </bin/sh #{nc['bootstrap_guest_path']}/#{nc['bootstrap_script_path']} #{nc['bootstrap_script_args']}>" if debug
        config.vm.provision 'shell', inline: "/bin/sh #{nc['bootstrap_guest_path']}/#{nc['bootstrap_script_path']} #{nc['bootstrap_script_args']}"
        if nc['update_packages'] == true
          puts "\n#{nc['name']}: update_packages = #{nc['update_packages']} and update_packages_command = #{nc['update_packages_command']}" if debug
          config.vm.provision 'shell', inline: nc['update_packages_command']
          if nc['shutdown'] == true
            puts "\n#{nc['name']}: shutdown = #{nc['shutdown']}" if debug
            config.vm.provision 'shell', inline: nc['shutdown_command']
          end
        end
      else
        puts "\n#{nc['name']}: NOT using provisioner for bootstrap" if debug
      end
    end
  end
end
