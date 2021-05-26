require 'bundler/setup'
require 'rake/testtask'

# load the spec, we use it below
spec = Gem::Specification.load('httpdisk.gemspec')

#
# testing
# don't forget about TESTOPTS="--verbose" rake
#

# test (default)
Rake::TestTask.new do
  _1.libs << 'test'
  _1.warning = false # https://github.com/lostisland/faraday/issues/1285
end
task default: :test

# Watch rb files, run tests whenever something changes
task :watch do
  # https://superuser.com/a/665208 / https://unix.stackexchange.com/a/42288
  system("while true; do find . -name '*.rb' | entr -c -d rake; test $? -gt 128 && break; done")
end

#
# pry
#

task :pry do
  system 'pry -I lib -r httpdisk.rb'
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
