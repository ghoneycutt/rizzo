#!/usr/bin/env ruby

require 'json'
require 'yaml'

input = ARGV[0]

json_data = File.read(input)
data = JSON.parse(json_data)
output = input.gsub('.json', '.yaml')
puts output
File.open(output, 'w') do |o|
  o.write(data.to_yaml)
end
