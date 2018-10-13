require 'rzo/app/subcommand'
module Rzo
  class App
    ##
    # Load all rizzo config files and print the config
    class Config < Subcommand
      attr_reader :config
      def run
        exit_status = 0
        load_config!
        write_file(opts[:output]) { |fd| fd.puts(config.to_yaml) }
        exit_status
      end
    end
  end
end
