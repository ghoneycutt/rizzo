# simplecov needs to be first for coverage to work properly.
require 'simplecov'
require 'bundler/setup'
require 'rzo'
require 'pathname'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  def fixture(fpath)
    fp = Pathname.new(__FILE__) + '../fixtures/' + fpath
    File.read(fp.to_s)
  end
end
