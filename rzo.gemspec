lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rzo/version'

Gem::Specification.new do |spec|
  spec.name          = 'rzo'
  spec.version       = Rzo.version
  spec.licenses      = ['Apache-2.0']
  spec.authors       = ['Garrett Honeycutt', 'Jeff McCune']
  spec.email         = ['code@learnpuppet.com']

  spec.summary       = 'Rizzo (rzo) is a tool for working with Vagrant and layered Puppet control repos'
  spec.description   = 'Rizzo (rzo) is a tool for working with Vagrant and layered Puppet control repos'
  spec.homepage      = 'https://github.com/ghoneycutt/rizzo'

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'guard', '~> 2.14'
  spec.add_development_dependency 'guard-rspec', '~> 4.7'
  spec.add_development_dependency 'guard-rubocop', '~> 1.3'
  spec.add_development_dependency 'guard-shell', '~> 0.7'
  spec.add_development_dependency 'guard-yard', '~> 2.2'
  spec.add_development_dependency 'pry', '~> 0.10'
  spec.add_development_dependency 'pry-stack_explorer', '~> 0.4'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.49'
  spec.add_development_dependency 'simplecov', '~> 0.14'
  spec.add_development_dependency 'yard', '~> 0.9'
  spec.add_dependency 'deep_merge', '~> 1.1'
  spec.add_dependency 'json', '~> 2.1'
  spec.add_dependency 'json-schema', '~> 2.8'
end
