require 'rzo/app'
require 'pathname'
require 'json-schema'
# rubocop:disable Style/GuardClause
module Rzo
  class App
    ##
    # Mix-in module providing configuration validation methods and safety
    # checking.  The goal is to provide useful feedback to the end user in the
    # situation where ~/.rizzo.yaml is configured to point at directories which
    # do not exist, have missing keys, etc...
    # rubocop:disable Metrics/ModuleLength
    module ConfigValidation
      ## Rizzo configuration schema for the personal configuration file at
      # ~/.rizzo.yaml.  Minimum necessary to load the complete configuration from
      # all control repositories.
      RZO_PERSONAL_CONFIG_SCHEMA = {
        '$schema' => 'http://json-schema.org/draft/schema#',
        title: 'Personal Configuration',
        description: 'Rizzo personal configuration file',
        type: 'object',
        properties: {
          defaults: {
            type: 'object',
          },
          control_repos: {
            type: 'array',
            items: { type: 'string' },
            uniqueItems: true,
          },
        },
        required: ['control_repos'],
      }.freeze
      ## Rizzo complete configuration schema.  This should move to a JSON file outside
      # the code.
      RZO_REPO_CONFIG_SCHEMA = {
        type: 'object',
        required: %w[defaults control_repos puppetmaster],
        properties: {
          defaults: {
            type: 'object',
            required: ['bootstrap_repo_path'],
            properties: {
              bootstrap_repo_path: {
                type: 'string',
                pattern: '^([a-zA-Z]:){0,1}(/[^/]+)+$',
              },
            },
          },
          puppetmaster: {
            type: 'object',
            required: %w[name modulepath synced_folders],
            properties: {
              name: {
                type: 'array',
                items: { type: 'string' },
              },
              modulepath: {
                type: 'array',
                items: { type: 'string' },
              },
              synced_folders: {
                '$schema' => 'http://json-schema.org/draft/schema#',
                type: 'object',
                properties: {
                  '/' => {},
                  patternProperties: {
                    '^(/[^/]+)+$' => {},
                  },
                  additionalProperties: false,
                  required: ['/'],
                }
              },
            },
          },
          control_repos: {
            type: 'array',
            items: { type: 'string' },
            uniqueItems: true,
          },
          nodes: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[name hostname ip],
              properties: {
                name: { type: 'string' },
                hostname: { type: 'string' },
                ip: { type: 'string' },
                memory: {
                  type: 'string',
                  pattern: '^[0-9]+$'
                },
                forwarded_ports: {
                  type: 'array',
                  items: {
                    type: 'object',
                    required: %w[guest host],
                    properties: {
                      guest: {
                        type: 'string',
                        pattern: '^[0-9]+$',
                      },
                      host: {
                        type: 'string',
                        pattern: '^[0-9]+$',
                      },
                    },
                  },
                },
              },
            },
            uniqueItems: true,
          }
        },
      }.freeze
      RZO_NODE_SCHEMA = {
        type: 'object',
        required: %w[box],
        properties: {
          box: {
            type: 'string',
          },
        },
      }.freeze
      # The checks to execute, in order.  Each method must return nil if there
      # are no issues found.  Otherwise, the check should return either one, or
      # an array of Issue instances.
      CHECKS_PERSONAL_CONFIG = %i[validate_personal_schema validate_control_repos].freeze
      CHECKS_REPO_CONFIG = %i[validate_schema validate_defaults_key validate_control_repos].freeze
      CHECKS_NODES = %i[validate_nodes].freeze

      ##
      # Class to model an issue found during validation
      class Issue
        attr_accessor :message

        def initialize(msg)
          self.message = msg
        end

        def to_s
          message
        end
      end

      ##
      # Compute Issues given a config map (base or complete), and an Array of
      # methods to execute.
      #
      # @param [Array<Symbol>] checks the method identifiers to execute, passing
      #   config.  These methods must return nil (no issue found), an Issue
      #   instance, or Array<Instance> for multiple issues found.
      #
      # @param [Hash] config the config hash, either a base configuration or a
      #   fully merged configuration.
      #
      # @return [Array<Issue>] Array of issue instances, or an empty array if no
      #   issues found with the config.
      def compute_issues(checks, config)
        ctx = self
        checks.each_with_object([]) do |mth, ary|
          debug "Checking config for #{mth} issues"
          if issue = ctx.send(mth, config)
            # May get back an Array<Issue> or one Issue
            ary.concat([*issue])
          end
        end
      end

      ##
      # Validate a personal configuration, typically originating from
      # ~/.rizzo.yaml. This configuration is necessary to build a complete
      # control repo configuration using the top level control repo. This
      # validation focuses on the minimum necessary configuration to bootstrap
      # the complete configuration, primarily the repo locations and existence.
      def validate_personal_config!(config)
        issues = compute_issues(CHECKS_PERSONAL_CONFIG, config)
        if issues.empty?
          debug 'No issues detected with the personal configuration.'
        else
          validate_inform!(issues)
        end
      end

      ##
      # Validate a complete loaded configuration.  This is distinct from a base
      # configuration in that the YAML files in each control repository have
      # already been merged, in order, on top of the base configuration
      # originating at ~/.rizzo.yaml.  This implements safety checking.  These
      # methods are expected to execute within the context of a
      # Rzo::App::Subcommand instance, therefore log methods and the parsed
      # configuration are assumed to be available.
      #
      # The approach is to collect an Array of Issue instances.  If issues are
      # found, control is handed off to validate_inform! to inform the user of
      # the issues and potentially abort the program.
      #
      # @param [Hash] config the config hash, fully merged by load_config!
      def validate_complete_config!(config)
        issues = compute_issues(CHECKS_REPO_CONFIG, config)
        if issues.empty?
          debug 'No issues detected with the complete, merged configuration.'
        else
          validate_inform!(issues)
        end
      end

      ##
      # Validate using
      # [json-schema](https://github.com/ruby-json-schema/json-schema)
      #
      # @return [Issue,nil] Issue found, or nil if no issues found.
      def validate_schema(config)
        if JSON::Validator.validate(RZO_REPO_CONFIG_SCHEMA, config)
          debug 'No schema violations found in loaded config.'
          return nil
        else
          err_msgs = JSON::Validator.fully_validate(RZO_REPO_CONFIG_SCHEMA, config)
          return err_msgs.map { |msg| Issue.new("Schema violation: #{msg}") }
        end
      end

      ##
      # Validate the configuration has a top level key named "defaults" and the
      # value is a Hash map.
      # rubocop:disable Metrics/MethodLength
      #
      # @return [Issue,nil] Issue found, or nil if no issues found.
      def validate_defaults_key(config)
        if defaults = config['defaults']
          return Issue.new('Top level key "defaults" must have a Hash value') unless defaults.is_a? Hash
        else
          return Issue.new('Configuration does not contain top level "defaults" key')
        end
        if pth = defaults['bootstrap_repo_path']
          return Issue.new('#/defaults/bootstrap_repo_path is not a String') unless pth.is_a? String
        else
          return Issue.new 'Configuration "defaults" value does not contain a '\
            '"bootstrap_repo_path" key.  For example, '\
            '{"defaults":{"bootstrap_repo_path":"/tmp/foo"}}'
        end
        validate_existence(pth, '#/defaults/bootstrap_repo_path value of ')
      end
      # rubocop:enable Metrics/MethodLength

      ##
      # Validate the top level "control_repos" key, which should have a value of
      # Array<String> where each string value is a fully qualified path.
      #
      # @return [Issue,nil] Issue found, or nil if no issues found.
      def validate_control_repos(config)
        if repos = config['control_repos']
          return Issue.new('Top level key "control_repos" must have an Array value') unless repos.is_a? Array
        else
          return Issue.new('Top level key "control_repos" is not specified.  It must be an Array of paths to your control repos.')
        end
        repos.each_with_object([]) do |pth, ary|
          if issue = validate_existence(pth, '#/control_repos')
            ary << issue
          end
        end
      end

      ##
      # Given a string, validate it's a fully qualified path, readable, and a
      # git directory.
      #
      # @return [Issue,Array<Issue>,nil] nil if no issues found, or one or more
      #   Issue instances.
      def validate_existence(path, prefix = '')
        pn = Pathname.new(path)
        git = pn + '.git'
        return Issue.new("#{prefix}#{pn} is not an absolute path.  It must be fully qualified, not relative") unless pn.absolute?
        return Issue.new("#{prefix}#{pn} is not a directory.  Has it been cloned?") unless pn.directory?
        return Issue.new("#{prefix}#{pn} is not readable.  Are permissions correct?") unless pn.readable?
        return Issue.new("#{prefix}#{git} does not exist.  Has #{git.dirname} been cloned properly?") unless git.directory?
      end

      ##
      # Validate the personal configuration, focus on ensuring the rest of the
      # configuration can load properly.
      #
      # @return [Issue,Array<Issue>,nil] nil if no issues found, or one or more
      #   Issue instances.
      def validate_personal_schema(config)
        if JSON::Validator.validate(RZO_PERSONAL_CONFIG_SCHEMA, config)
          debug 'No schema violations found in personal configuration file.'
          return nil
        else
          err_msgs = JSON::Validator.fully_validate(RZO_PERSONAL_CONFIG_SCHEMA, config)
          return err_msgs.map { |msg| Issue.new("Personal config problem: #{msg}") }
        end
      end

      # Inform the user about issues found and exit the program.  The top level
      # exception handler is not expected to display much information on
      # validation errors.  This method is expected to provide the helpful
      # guidance.
      #
      # @param [Array<Issue>] issues Array of issues.  Each hash must have at
      # least a key named `:message`
      def validate_inform!(issues, opts = {})
        if opts[:validate]
          msg = "Validation issues found with #{opts[:config]}"
          exc = ErrorAndExit.new(msg, 2)
          exc.log_fatal = issues.each_with_object([]) { |i, a| a << i.to_s }
          raise exc
        else
          issues.each { |i| log.warn(i.to_s) }
        end
      end

      def validate_nodes!(nodes)
        issues = compute_issues(CHECKS_NODES, nodes)
        if issues.empty?
          debug 'No issues detected with the node definitions.'
        else
          validate_inform!(issues, { :validate => true, :config => 'nodes' })
        end
      end

      # Validate node hash
      def validate_nodes(nodes)
        if JSON::Validator.validate(RZO_NODE_SCHEMA, nodes, :list => true)
          debug 'No node definition violations found.'
          return nil
        else
          err_msgs = JSON::Validator.fully_validate(RZO_NODE_SCHEMA, nodes, :list => true)
          return err_msgs.map { |msg| Issue.new("Node definition problem: #{msg}") }
        end
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
# rubocop:enable Style/GuardClause
