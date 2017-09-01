require 'pathname'
require 'rzo/logging'
require 'deep_merge'
module Rzo
  class App
    # The base class for subcommands
    class Subcommand
      include Logging
      extend Logging
      # The options hash injected from the application controller via the
      # initialize method.
      attr_reader :opts
      # The Rizzo configuration after loading ~/.rizzo.json (--config).
      # See #load_config!
      attr_reader :config

      ##
      # Delegated method to mock with fixture data.
      def self.load_rizzo_config(fpath)
        config_file = Pathname.new(fpath).expand_path
        raise ErrorAndExit, "Cannot read config file #{config_file}" unless config_file.readable?
        config = JSON.parse(config_file.read)
        log.debug "Loaded #{config_file}"
        config
      rescue JSON::ParserError => e
        raise ErrorAndExit, "Could not parse rizzo config #{config_file} #{e.message}"
      end

      # Initialize a subcommand with options injected by the application
      # controller.
      #
      # @param [Hash] opts the Options hash initialized by the Application
      # controller.
      def initialize(opts = {}, stdout = $stdout, stderr = $stderr)
        @opts = opts
        @stdout = stdout
        @stderr = stderr
        reset_logging!(opts)
      end

      ##
      # Default run method.  Override this method in a subcommand sub-class
      #
      # @return [Fixnum] the exit status of the subcommand.
      def run
        error "Implement the run method in subclass #{self.class}"
        1
      end

      private

      ##
      # Load rizzo configuration.  Populate @config.
      #
      # Read rizzo configuration by looping through control repos and stopping
      # at first match and merge on top of local, defaults (~/.rizzo.json)
      def load_config!
        config = load_rizzo_config(opts[:config])
        validate_config(config)
        repos = config['control_repos']
        @config = load_repo_configs(config, repos)
        debug "Merged configuration: \n#{JSON.pretty_generate(@config)}"
        validate_forwarded_ports(@config)
        validate_ip_addresses(@config)
        @config
      end

      ##
      # Given a list of repository paths, load .rizzo.json from the root of each
      # repository and return the result merged onto config.  The merging
      # behavior is implemented by
      # [deep_merge](http://www.rubydoc.info/gems/deep_merge/1.1.1)
      #
      # @param [Hash] config the starting config hash.  Repo config maps will be
      #   merged on top of this starting map.
      #
      # @param [Array] repos the list of repositories to load .rizzo.json from.
      #
      # @return [Hash] the merged configuration hash.
      def load_repo_configs(config = {}, repos = [])
        repos.each_with_object(config.dup) do |repo, hsh|
          fp = Pathname.new(repo).expand_path + '.rizzo.json'
          if fp.readable?
            hsh.deep_merge!(load_rizzo_config(fp))
          else
            log.debug "Skipped #{fp} (it is not readable)"
          end
        end
      end

      ##
      # Basic validation of the configuration file content.
      #
      # @param [Hash] config the configuration map
      def validate_config(config)
        errors = []
        errors.push 'control_repos key is not an Array' unless config['control_repos'].is_a?(Array)
        errors.each { |l| log.error l }
        raise ErrorAndExit, 'Errors found in config file.  Cannot proceed.' unless errors.empty?
      end

      ##
      # Check for duplicate forwarded host ports across all hosts and exit
      # non-zero with an error message if found.
      def validate_forwarded_ports(config)
        host_ports = []
        [*config['nodes']].each do |node|
          [*node['forwarded_ports']].each do |hsh|
            port = hsh['host'].to_i
            raise_port_err(port, node['name']) if host_ports.include?(port)
            host_ports.push(port)
          end
        end
        log.debug "host_ports = #{host_ports}"
      end

      ##
      # Check for duplicate forwarded host ports across all hosts and exit
      # non-zero with an error message if found.
      def validate_ip_addresses(config)
        ips = []
        [*config['nodes']].each do |node|
          if ip = node['ip']
            raise_ip_err(ip, node['name']) if ips.include?(ip)
            ips.push(ip)
          end
        end
        log.debug "ips = #{ips}"
      end

      ##
      # Helper to raise a duplicate port error
      def raise_port_err(port, node)
        raise ErrorAndExit, "host port #{port} on node #{node} " \
          'is a duplicate.  Ports must be unique.  Check .rizzo.json ' \
          'files in each control repository for duplicate forwarded_ports entries.'
      end

      ##
      # Helper to raise a duplicate port error
      def raise_ip_err(ip, node)
        raise ErrorAndExit, "host ip #{ip} on node #{node} " \
          'is a duplicate.  IP addresses must be unique.  Check .rizzo.json ' \
          'files in each control repository for duplicate ip entries'
      end

      ##
      # Load the base configuration and return it as a hash.  This is necessary
      # to get access to the `'control_repos'` top level key, which is expected
      # to be an Array of fully qualified paths to control repo base
      # directories.
      #
      # @param [String] fpath The fully qualified path to the configuration file
      #   to load.
      #
      # @return [Hash] The configuration map
      def load_rizzo_config(fpath)
        self.class.load_rizzo_config(fpath)
      end

      ##
      # Write a file by yielding a file descriptor to the passed block.  In the
      # case of opening a file, the FD will automatically be closed.
      def write_file(filepath)
        case filepath
        when 'STDOUT' then yield @stdout
        when 'STDERR' then yield @stderr
        else File.open(filepath, 'w') { |fd| yield fd }
        end
      end
    end
  end
end
