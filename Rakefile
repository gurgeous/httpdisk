require 'bundler/setup'
require 'rake/testtask'

# load the spec, we use it below
spec = Gem::Specification.load('httpdisk.gemspec')

#
# testing
# don't forget about TESTOPTS="--verbose" rake
#

# test (default)
Rake::TestTask.new { _1.libs << 'test' }
task default: :test

# Watch files, run tests whenever something changes
task :watch do
  system('find . | entr -c rake test')
end

#
# pry
#

task :pry do
  system 'pry -I lib -r httpdisk.rb'
end

#
# gem
#

task :build do
  system('gem build --quiet httpdisk.gemspec', exception: true)
end

task install: :build do
  system("gem install --quiet httpdisk-#{spec.version}.gem", exception: true)
end

task release: :build do
  raise "looks like git isn't clean" unless `git status --porcelain`.empty?

  system("git tag -a #{spec.version} -m 'Tagging #{spec.version}'", exception: true)
  system('git push --tags', exception: true)
  system("gem push httpdisk-#{spec.version}.gem", exception: true)
end
