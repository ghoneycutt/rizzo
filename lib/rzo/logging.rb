require 'logger'
require 'stringio'
require 'syslog/logger'
module Rzo
  ##
  # Support module to mix into a class for consistent logging behavior.
  module Logging
    ##
    # Reset the global logger instance and return it as an object.
    #
    # @return [Logger] initialized logging instance
    def self.reset_logging!(opts)
      logger = opts[:syslog] ? syslog_logger : stream_logger(opts)
      @log = logger
    end

    ##
    # Return a new Syslog::Logger instance configured for syslog output
    def self.syslog_logger
      # Use the daemon facility, matching Puppet behavior.
      Syslog::Logger.new('rzo', Syslog::LOG_DAEMON)
    end

    ##
    # Return a new Logger instance configured for file output
    def self.stream_logger(opts)
      out = map_file_option(opts[:logto])
      logger = Logger.new(out)
      logger.level = Logger::WARN
      logger.level = Logger::INFO if opts[:verbose]
      logger.level = Logger::DEBUG if opts[:debug]
      logger
    end

    ##
    # Logging is handled centrally, the helper methods will delegate to the
    # centrally configured logging instance.
    def self.log
      @log || reset_logging!(opts)
    end

    ##
    # Map a file option to STDOUT, STDERR or a fully qualified file path.
    #
    # @param [String] filepath A relative or fully qualified file path, or the
    #   keyword strings 'STDOUT' or 'STDERR'
    #
    # @return [String] file path or $stdout or $sederr
    def self.map_file_option(filepath)
      case filepath
      when 'STDOUT' then $stdout
      when 'STDERR' then $stderr
      when 'STDIN' then $stdin
      when 'STRING' then StringIO.new
      else File.expand_path(filepath)
      end
    end

    def map_file_option(filepath)
      ::Rzo::Logging.map_file_option(filepath)
    end

    def log
      ::Rzo::Logging.log
    end

    ##
    # Reset the logging system, requires command line options to have been
    # parsed.
    #
    # @param [Hash<Symbol, String>] opts Options hash, passed to the support module
    def reset_logging!(opts)
      ::Rzo::Logging.reset_logging!(opts)
    end

    ##
    # Logs a message at the fatal (syslog err) log level
    def fatal(msg)
      log.fatal msg
    end

    ##
    # Logs a message at the error (syslog warning) log level.
    # i.e. May indicate that an error will occur if action is not taken.
    # e.g. A non-root file system has only 2GB remaining.
    def error(msg)
      log.error msg
    end

    ##
    # Logs a message at the warn (syslog notice) log level.
    # e.g. Events that are unusual, but not error conditions.
    def warn(msg)
      log.warn msg
    end

    ##
    # Logs a message at the info (syslog info) log level
    # i.e. Normal operational messages that require no action.
    # e.g. An application has started, paused or ended successfully.
    def info(msg)
      log.info msg
    end

    ##
    # Logs a message at the debug (syslog debug) log level
    # i.e.  Information useful to developers for debugging the application.
    def debug(msg)
      log.debug msg
    end

    ##
    # Helper method to write output, used for stubbing out the tests.
    #
    # @param [String, IO] output the output path or a IO stream
    def write_output(str, output)
      if output.is_a?(IO)
        output.puts(str)
      else
        File.open(output, 'w+') { |f| f.puts(str) }
      end
    end

    ##
    # Helper method to read from STDIN, or a file and execute an arbitrary block
    # of code.  A block must be passed which will recieve an IO object in the
    # event input is a readable file path.
    def input_stream(input)
      if input.is_a?(IO)
        yield input
      else
        File.open(input, 'r') { |stream| yield stream }
      end
    end

    ##
    # Alternative to puts, writes output to STDERR by default and logs at level
    # info.
    def say(msg)
      log.info(msg)
      @stderr.puts(msg)
    end
  end
end
