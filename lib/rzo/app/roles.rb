require 'rzo/app/subcommand'
module Rzo
  class App
    ##
    # Load all rizzo config files and print the roles
    class Roles < Subcommand
      attr_reader :config

      ##
      # Map the combined config to a list of roles.  No effort is made to sort
      # them.
      #
      # @return [Array<String>] array of strings identifying each Puppet role
      # name.  This is the same as the name of the VM.
      def roles
        return [] unless nodes = config['nodes']
        nodes.each_with_object([]) do |node, a|
          next unless node['name']
          a << node['name']
        end
      end

      def run
        exit_status = 0
        load_config!
        write_file(opts[:output]) { |fd| fd.puts(roles) }
        exit_status
      end
    end
  end
end
