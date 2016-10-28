require 'json'
require 'rubocop/rake_task'
RuboCop::RakeTask.new

desc 'Validation tests'
task :validate do
  puts '=== Validating JSON (*.json) files'
  Dir.glob('**/*.json', File::FNM_DOTMATCH).each do |json_file|
    puts json_file
    json = File.read(json_file)
    JSON.parse(json)
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

task :default => [:validate]
