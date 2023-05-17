require "yaml"
require "json"

raise if ARGV.size != 1

input = ARGV[0]

in_list = JSON.parse(File.read(input), symbolize_names: true)

out_list = []
in_list.each do |user|
  out_list << "#{user[:id_str]} # #{user[:screen_name]} [#{user[:name]}] #{user[:description].gsub("\n", "")}"
end

puts out_list.join("\n") + "\n"
