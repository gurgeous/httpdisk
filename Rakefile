require 'bundler/setup'
require 'rake/testtask'

# load the spec, we use it below
spec = Gem::Specification.load('httpdisk.gemspec')

#
# testing
# don't forget about TESTOPTS="--verbose" rake
#

# test (default)
Rake::TestTask.new
task default: :test

# Watch rb files, run tests whenever something changes
task :watch do
  sh "find . -name '*.rb' | entr -c rake"
end

#
# pry
#

task :pry do
  sh 'pry -I lib -r httpdisk.rb'
end

#
# rubocop
#

task :rubocop do
  sh 'bundle exec rubocop -A .'
end

#
# gem
#

task :build do
  sh 'gem build --quiet httpdisk.gemspec'
end

task install: :build do
  sh "gem install --quiet httpdisk-#{spec.version}.gem"
end

task release: %i[rubocop test build] do
  raise "looks like git isn't clean" unless `git status --porcelain`.empty?

  sh "git tag -a #{spec.version} -m 'Tagging #{spec.version}'"
  sh 'git push --tags'
  sh "gem push httpdisk-#{spec.version}.gem"
end
