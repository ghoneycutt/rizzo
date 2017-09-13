# Convert a lib path to a spec path
def to_spec(path)
  path.sub('lib/', 'spec/').sub(/\.rb$/, '_spec.rb')
end

# guard 'yard', server: false do
#   watch(%r{app\/.+\.rb})
#   watch(%r{lib\/.+\.rb})
#   watch(%r{ext\/.+\.c})
# end

guard :rubocop do
  watch(/.+\.rb$/)
  watch('Gemfile')
  watch('Guardfile')
  watch('Vagrantfile')
  watch('rzo.gemspec')
  watch(%r{(?:.+/)?\.rubocop(?:_todo)?\.yml$}) { |m| File.dirname(m[0]) }
end

guard :shell do
  require 'guard/rspec/dsl'
  require 'pathname'
  dsl = Guard::RSpec::Dsl.new(self)

  runner = proc do |p|
    if system("rspec -fd #{p}")
      n 'Spec tests pass', 'rspec', :success
    else
      n 'Spec tests fail', 'rspec', :failed
    end
    nil
  end

  # Feel free to open issues for suggestions and improvements

  # RSpec files
  rspec = dsl.rspec
  watch(rspec.spec_helper) do |m|
    runner.call(m[0])
  end
  watch(rspec.spec_support) do
    runner.call(m[0])
  end
  watch rspec.spec_files do |m|
    runner.call(m[0])
  end

  # Ruby files
  ruby = dsl.ruby
  watch(ruby.lib_files) do |m|
    spec = Pathname.new(to_spec(m[0]))
    runner.call(spec.to_s) if spec.readable?
  end
end
# vim:ft=ruby
