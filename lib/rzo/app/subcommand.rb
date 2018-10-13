require 'pathname'
require 'rzo/logging'
require 'deep_merge'
require 'rzo/app/config_validation'
require 'yaml'
module Rzo
  class App
    # The base class for subcommands
    # rubocop:disable Metrics/ClassLength
    class Subcommand
      include ConfigValidation
      include Logging
      extend Logging
      # The options hash injected from the application controller via the
      # initialize method.
      attr_reader :opts
      # The Rizzo configuration after loading ~/.rizzo.yaml (--config).
      # See #load_config!
      attr_reader :config
      # The present working directory at startup
      attr_reader :pwd

      ##
      # Delegated method to mock with fixture data.
      def self.load_rizzo_config(fpath)
        config_file = Pathname.new(fpath).expand_path
        raise ErrorAndExit, "Cannot read config file #{config_file}" unless config_file.readable?

        config = YAML.safe_load(config_file.read)
        log.debug "Loaded #{config_file}"
        config
      rescue Psych::SyntaxError => e
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
        @pwd = Dir.pwd
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
      # at first match and merge on top of local, defaults (~/.rizzo.yaml)
      def load_config!
        config = load_rizzo_config(opts[:config])
        validate_personal_config!(config)
        repos = reorder_repos(config['control_repos'])
        config['control_repos'] = repos
        @config = load_repo_configs(config, repos)
        debug "Merged configuration: \n#{@config.to_yaml}"
        # TODO: Move these validations to an instance method?
        validate_complete_config!(@config)
        # validate_forwarded_ports(@config)
        # validate_ip_addresses(@config)
        @config
      end

      ##
      # Given a list of repository paths, load .rizzo.yaml from the root of each
      # repository and return the result merged onto config.  The merging
      # behavior is implemented by
      # [deep_merge](http://www.rubydoc.info/gems/deep_merge/1.1.1)
      #
      # @param [Hash] config the starting config hash.  Repo config maps will be
      #   merged on top of this starting map.
      #
      # @param [Array] repos the list of repositories to load .rizzo.yaml from.
      #
      # @return [Hash] the merged configuration hash.
      def load_repo_configs(config = {}, repos = [])
        repos.each_with_object(config.dup) do |repo, hsh|
          fp = Pathname.new(repo).expand_path + '.rizzo.yaml'
          if readable?(fp.to_s)
            hsh.deep_merge!(load_rizzo_config(fp.to_s))
          else
            log.debug "Skipped #{fp} (it is not readable)"
          end
        end
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
          'is a duplicate.  Ports must be unique.  Check .rizzo.yaml ' \
          'files in each control repository for duplicate forwarded_ports entries.'
      end

      ##
      # Helper to raise a duplicate port error
      def raise_ip_err(ip, node)
        raise ErrorAndExit, "host ip #{ip} on node #{node} " \
          'is a duplicate.  IP addresses must be unique.  Check .rizzo.yaml ' \
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

      # helper method to to stub in tests
      def readable?(path)
        File.readable?(path)
      end

      ##
      # Memoized method to return the fully qualified path to the current rizzo
      # project directory, based on the pwd.  The project directory is the
      # dirname of the full path to a `.rizzo.yaml` config file.  Return false
      # if not a project directory.  ~/.rizzo.yaml is considered a personal
      # configuration and not a project configuration.
      #
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def project_dir(path)
        return @project_dir unless @project_dir.nil?

        rizzo_file = Pathname.new("#{path}/.rizzo.yaml")
        personal_config = Pathname.new(File.expand_path('~/.rizzo.yaml'))
        iterations = 0
        while @project_dir.nil? && iterations < 100
          iterations += 1
          if readable?(rizzo_file.to_s) && rizzo_file != personal_config
            @project_dir = rizzo_file.dirname.to_s
          else
            rizzo_file = rizzo_file.dirname.dirname + '.rizzo.yaml'
            @project_dir = false if rizzo_file.dirname.root?
          end
        end
        @project_dir
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      ##
      # Given a list of control repositories, determine if the user's runtime
      # pwd is in a control repository.  If it is, move that control repository
      # to the top level.  If the user is inside a control repository and
      def reorder_repos(repos = [])
        if path = project_dir(pwd)
          new_repos = repos - [path]
          new_repos.unshift(path)
        else
          repos
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
