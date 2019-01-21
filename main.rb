require 'pry'
require 'colorize'
require 'yaml'

def run_cmds(array)
  %x(#{array.join(" && ")})
end

CONFIG_FILE_PATH = '.config.yml'

CONFIG = YAML.load_file(CONFIG_FILE_PATH)

TARGET_DIR = CONFIG['target_dir'] || fail("target_dir is not set is #{CONFIG_FILE_PATH}")
TARGET_BRANCH = CONFIG['target_branch'] || fail("target_branch is not set is #{CONFIG_FILE_PATH}")

run_cmds [
             "cd #{TARGET_DIR}",
             "git reset --hard",
             "git checkout #{TARGET_BRANCH}",
             "cp .rubocop.yml #{Dir.pwd}/rubocop.yml"]

PERIODS = [7, 30, 90, 365]
results = {}
([0] + PERIODS).each do |days|
  expr = "ruby -e \"puts Dir['{config,app,lib}/**/*.rb'].join(' ')\""

  checkout = if days == 0
               "git checkout #{TARGET_BRANCH}"
             else
               "git checkout $(git rev-list -n 1 --before='#{days} days ago' #{TARGET_BRANCH})"
             end

  run_cmds [
               "cd #{TARGET_DIR}",
               "git reset --hard",
               checkout,
           ]

  FileUtils.cp "#{Dir.pwd}/rubocop.yml", "#{TARGET_DIR}/.rubocop.yml"

  cmds = [
      "cd #{TARGET_DIR}",
      "rubocop $(#{expr}) -f j | jq .summary.offense_count"
  ]

  results[days] = run_cmds(cmds).chomp.split("\n").last.to_i
end

# results = { 0 => 23559, 7 => 23537, 30 => 23602, 90 => 23658, 365 => 24727 }

puts "\n\nNow: #{results[0]} Offences"
puts "\nOffences days ago:"

PERIODS.each do |days|
  diff = results[0] - results[days]
  color = diff < 0 ? :green : :red
  perc = ((100.0 * diff / results[days]).round(1)).to_s + "%"

  puts "#{days.to_s.rjust(3)} days: #{diff.to_s.colorize(color)}\t #{perc.colorize(color)}"
  if days == 365
    puts "With such speed offences will be fixed in #{(results[days].to_f / -diff).round(1)} years"
  end
end

run_cmds [
             "cd #{TARGET_DIR}",
             "git reset --hard",
             "git checkout #{TARGET_BRANCH}"]
