##
# See rzo.rb for the main implementation.  This is a light-weight module
# strictly for version information.
module Rzo
  # The authoritative location of the rzo version.  It should be possible to
  # `require 'rizzo/version'` and access `Rizzo::VERSION` from third party
  # libraries and the gemspec.  The version is defined as a Semantic Version.
  VERSION = '0.8.0'.freeze

  ##
  # Return the SemVer string, e.g. `"0.1.0"`
  #
  # @return [String] e.g. "1.0.0"
  def self.version
    Rzo::VERSION
  end
end
