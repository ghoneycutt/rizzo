module Rzo
  ##
  # Mix-in module to handle all option parsing.  Options will be accessible from
  # the `opts` method.  This module is meant to be included in an App class.
  module OptionParsing
    attr_reader :argv, :env, :opts

    ##
    # Reset the @opts instance variable by parsing @argv and @env.  Operates
    # against duplicate copies of the argument vector avoid side effects.
    #
    # @return [Hash<Symbol, String>] Options hash
    def reset_options!
      @opts = parse_options(argv, env)
    end

    ##
    # Parse options using the argument vector and the environment hash as
    # input. Option parsing occurs in two phases, first the global options are
    # parsed. These are the options specified before the subcommand.  The
    # subcommand, if any, is matched, and subcommand specific options are then
    # parsed from the remainder of the argument vector.
    #
    # @param [Array] argv The argument vector, passed to the option parser.
    #
    # @param [Hash] env The environment hash, passed to the option parser to
    #   supply defaults not specified on the command line argument vector.
    #
    # @return [Hash<Symbol, String>] options hash
    def parse_options(argv, env)
      argv_copy = argv.dup
      opts = parse_global_options!(argv_copy, env)
      if subcommand = parse_subcommand!(argv_copy)
        opts[:subcommand] = subcommand
        sub_opts = parse_subcommand_options!(subcommand, argv_copy, env)
        opts.merge!(sub_opts)
      end
      opts
    end

    ##
    # Parse out the global options, the ones specified between the main
    # executable and the subcommand argument.
    #
    # Modifies argv as a side effect, shifting elements from the array until
    # the first unknown option is found, which is assumed to be the subcommand
    # name.
    #
    # @return [Hash<Symbol, String>] Global options
    # rubocop:disable Metrics/MethodLength
    def parse_global_options!(argv, env)
      semver = Rzo::VERSION
      prog_name = NAME
      Rzo::Trollop.options(argv) do
        stop_on_unknown
        version "#{prog_name} #{semver} (c) 2017 Garrett Honeycutt"
        banner BANNER
        log_msg = 'Log file to write to or keywords '\
          'STDOUT, STDERR {RZO_LOGTO}'
        opt :logto, log_msg, default: env['RZO_LOGTO'] || 'STDERR'
        opt :syslog, 'Log to syslog', default: false, conflicts: :logto
        opt :verbose, 'Set log level to INFO'
        opt :debug, 'Set log level to DEBUG'
        opt :config, 'Rizzo config file {RZO_CONFIG}',
            default: env['RZO_CONFIG'] || '~/.rizzo.json'
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    ##
    # Extract the subcommand, if any, from the arguments provided.  Modifies
    # argv as a side effect, shifting the subcommand name if it is present.
    #
    # @return [String] The subcommand name, e.g. 'backup' or 'restore', or
    #   false if no arguments remain in the argument vector.
    def parse_subcommand!(argv)
      argv.shift || false
    end

    ##
    # Parse the subcommand options.  This method branches out because each
    # subcommand can have quite different options, unlike global options which
    # are consistent across all invocations of the application.
    #
    # Modifies argv as a side effect, shifting all options as things are
    # parsed.
    #
    # @return [Hash<Symbol, String>] Subcommand specific options hash
    # rubocop:disable Metrics/MethodLength
    def parse_subcommand_options!(subcommand, argv, env)
      prog_name = NAME
      case subcommand
      when 'config'
        Rzo::Trollop.options(argv) do
          banner "#{prog_name} #{subcommand} options:"
          opt :output, 'Config output', short: 'o', default: env['RZO_OUTPUT'] || 'STDOUT'
        end
      when 'generate'
        Rzo::Trollop.options(argv) do
          banner "#{prog_name} #{subcommand} options:"
          opt :vagrantfile, 'Output Vagrantfile', short: 'o', default: env['RZO_VAGRANTFILE'] || 'Vagrantfile'
        end
      else
        Rzo::Trollop.die "Unknown subcommand: #{subcommand.inspect}"
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    # The name of the executable, could be `rizzo` or `rzo`
    NAME = File.basename($PROGRAM_NAME).freeze

    # rubocop:disable Layout/IndentHeredoc
    BANNER = <<-"EOBANNER".freeze
usage: #{NAME} [GLOBAL OPTIONS] SUBCOMMAND [ARGS]
Sub Commands:

  config       Print out the combined rizzo json config
  generate     Initialize Vagrantfile in top control repo

Global options: (Note, command line arguments supersede ENV vars in {}'s)
    EOBANNER
  end
end
