
# read gem version
gemver := `cat lib/httpdisk/version.rb | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+"`

#
# dev
#

default: test

check: lint test

fmt:
  bundle exec rubocop -a

lint:
  @just banner lint...
  bundle exec rubocop

pry:
  bundle exec pry -I lib -r httpdisk.rb

test:
  @just banner test...
  bundle exec rake test

test-watch:
  @watchexec --clear=clear bundle exec rake test

#
# ci
#

ci:
  bundle install
  just check

#
# gem tasks
#

gem-push: check-git-status
  @just banner gem build...
  gem build httpdisk.gemspec
  @just banner tag...
  git tag -a "v{{gemver}}" -m "Tagging {{gemver}}"
  git push --tags
  @just banner gem push...
  gem push "httpdisk-{{gemver}}.gem"

#
# util
#

banner *ARGS:
  @printf '\e[42;37;1m[%s] %-72s \e[m\n' "$(date +%H:%M:%S)" "{{ARGS}}"

check-git-status:
  @if [ ! -z "$(git status --porcelain)" ]; then echo "git status is dirty, bailing."; exit 1; fi
