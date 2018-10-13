require 'yaml'
require 'rubocop/rake_task'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RuboCop::RakeTask.new
RSpec::Core::RakeTask.new(:spec)

desc 'Validation tests'
task :validate do
  puts '=== Validating YAML (*.yaml) files'
  filelist = FileList.new('**/*.yaml')
  filelist.exclude('.bundle/**')
  filelist.each do |yaml_file|
    puts yaml_file
    yaml = File.read(yaml_file)
    YAML.parse(yaml)
  end

  puts "\n=== Validating ruby (*.rb, Vagrantfile, Rakefile and Gemfile) files"
  Dir['**/*.rb', 'Vagrantfile', 'Rakefile', 'Gemfile'].each do |ruby|
    sh "ruby -c #{ruby}"
  end

  puts "\n=== Validating ERB (*.erb) files"
  Dir['**/*.erb'].each do |erb|
    sh "erb -P -x -T '-' #{erb} | ruby -c"
  end
end

task :default => %i[validate spec]
