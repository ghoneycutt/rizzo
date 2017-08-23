require 'rzo/app/subcommand'
require 'pp'
require 'erb'

module Rzo
  class App
    ##
    # Produce a `Vagrantfile` in the top level puppet control repo.
    #
    # Load all rizzo config files, then produce the Vagrantfile from an ERB
    # template.
    class Generate < Subcommand
      attr_reader :config

      # The main run method for the subcommand.
      def run
        exit_status = 0
        load_config!
        # Vagrantfile
        erbfile = File.expand_path('../templates/Vagrantfile.erb', __FILE__)
        content = vagrantfile_content(erbfile, config)
        write_file(opts[:vagrantfile]) { |fd| fd.write(content) }
        say "Wrote vagrant config to #{opts[:vagrantfile]}"
        exit_status
      end

      ##
      # Return a list of agent node definitions suitable for the Vagrantfile
      # template.
      #
      # @param [Hash] config The configuration hash used to fill in the ERB
      # template.
      #
      # @return [Array<Hash>] list of agent nodes to fill in the Vagrantfile
      # template.
      def vagrantfile_agents(config)
        pm_settings = puppetmaster_settings(config)
        agent_nodes = [*config['nodes']].reject do |n|
          pm_settings['name'].include?(n['name'])
        end

        agent_nodes.each do |n|
          n.deep_merge(config['defaults'])
          log.debug "puppetagent #{n['name']} = \n" + n.pretty_inspect
        end

        agent_nodes
      end

      ##
      # Return a list of puppetmaster node definitions suitable for the
      # Vagrantfile template.
      #
      # @param [Hash] config The configuration hash used to fill in the ERB
      # template.
      #
      # @return [Array<Hash>] list of puppet master nodes to fill in the
      # Vagrantfile template.
      #
      # rubocop:disable Metrics/AbcSize
      def vagrantfile_puppet_masters(config)
        pm_settings = puppetmaster_settings(config)
        pm_names = pm_settings['name']

        nodes = [*config['nodes']].find_all { |n| pm_names.include?(n['name']) }
        nodes.each do |n|
          n.deep_merge(config['defaults'])
          n.deep_merge(pm_settings)
          n[:puppetmaster] = true
          log.debug "puppetmaster #{n['name']} = \n" + n.pretty_inspect
        end
      end
      # rubocop:enable Metrics/AbcSize

      ##
      # Return the proxy configuration exception list as a string, or nil if not set.
      #
      # @param [Hash] config The configuration hash used to fill in the ERB
      # template.
      #
      # @return [String,nil] proxy exclusion list or nil if not specified.
      def proxy_config(config)
        # Proxy Setting
        return nil unless config['config']
        config['config']['no_proxy'] || DEFAULT_NO_PROXY
      end

      ##
      # Return a timestamp to embed in the output Vagrantfile.  This is a method
      # so it may be stubbed out in the tests.
      def timestamp
        Time.now
      end

      ##
      # Return a string which is the Vagrantfile content of a filled in
      # Vagrantfile erb template.  The configuration data parsed by load_config!
      # is expected as input, along with the template to fill in.
      #
      # The base templates directory is relative to the directory containing
      # this file.
      #
      # @param [String] template The fully qualified path to the ERB template.
      #
      # @param [Hash] config The configuration hash used to fill in the ERB
      # template.
      #
      # @return [String] the content of the filled in template.
      def vagrantfile_content(template, config)
        renderer = ERB.new(File.read(template), 0, '-')

        no_proxy = proxy_config(config)

        # Agent nodes [Array<Hash>]
        agent_nodes = vagrantfile_agents(config)
        # Puppet Master nodes [Array<Hash>]
        puppet_master_nodes = vagrantfile_puppet_masters(config)

        # nodes is used by the Vagrantfile.erb template
        nodes = [*puppet_master_nodes, *agent_nodes]
        content = renderer.result(binding)
        content
      end

      ##
      # dump out the puppetmaster settings from the config.
      def puppetmaster_settings(config)
        log.debug "config['puppetmaster'] = \n" + \
          config['puppetmaster'].pretty_inspect
        config['puppetmaster']
      end

      # Constants used by the Vagrantfile.erb template.
      DEFAULT_NO_PROXY = 'localhost,127.0.0.1'.freeze
    end
  end
end
