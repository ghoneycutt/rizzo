require 'rzo'
require 'rzo/logging'
require 'rzo/option_parsing'
require 'rzo/app/config'
require 'rzo/app/generate'
require 'rzo/app/roles'
require 'json'

module Rzo
  ##
  # The application controller.  An instance of this class models the
  # application lifecycle.  Input configuration follows the 12 factor model.
  #
  # The general lifecycle is:
  #
  #  * app = App.new()
  #  * app.parse_options!
  #  * app.run
  class App
    include Rzo::Logging
    include Rzo::OptionParsing

    ##
    # Exception used to exit the app from a subcommand.  Caught by the main run
    # method in the app controller
    class ErrorAndExit < StandardError
      attr_accessor :exit_status
      attr_accessor :log_fatal
      def initialize(message = nil, exit_status = 1)
        super(message)
        self.exit_status = exit_status
        self.log_fatal = []
      end
    end

    ##
    # @param [Array] argv The argument vector, passed to the option parser.
    #
    # @param [Hash] env The environment hash, passed to the option parser to
    #   supply defaults not specified on the command line argument vector.
    #
    # @return [App] the application instance.
    def initialize(argv = ARGV.dup, env = ENV.to_hash, stdout = $stdout, stderr = $stderr)
      @argv = argv
      @env = env
      @stdout = stdout
      @stderr = stderr
      reset!
    end

    ##
    # Reset all state associated with this application instance.
    def reset!
      reset_options!
      reset_logging!(opts)
      @api = nil
    end

    ##
    # Accessor to Subcommand::Generate
    def generate
      @generate ||= Generate.new(opts, @stdout, @stderr)
    end

    ##
    # Accessor to Subcommand::Config
    def config
      @config ||= Config.new(opts, @stdout, @stderr)
    end

    ##
    # Override this later to allow trollop to write to an intercepted file
    # descriptor for testing.  This will avoid trollop's behavior of calling
    # exit()
    def educate
      Trollop.educate
    end

    ##
    # The main application run method
    #
    # @return [Fixnum] the system exit code
    #
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def run
      case opts[:subcommand]
      when 'config'
        config.run
      when 'generate'
        generate.run
      when 'roles'
        Roles.new(opts, @stdout, @stderr).run
      else
        educate
      end
    rescue ErrorAndExit => e
      log.fatal e.message
      e.log_fatal.each { |m| log.fatal(m) }
      e.backtrace.each { |l| log.debug(l) }
      e.exit_status
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
  end
end
