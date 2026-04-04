default:
  just --list

#
# dev
#

check: lint test

fmt:
  rubocop -a

lint:
  rubocop

pry:
  pry -I lib -r httpdisk.rb

test:
  rake test

test-watch:
  watchexec --stop-timeout=0 --clear=clear just test


#
# gem tasks
#

gemver := `cat lib/httpdisk/version.rb | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+"`

gem-push: check-git-status
  just banner gem build...
  gem build httpdisk.gemspec
  just banner tag...
  git tag -a "v{{gemver}}" -m "Tagging {{gemver}}"
  git push --tags
  just banner gem push...
  gem push "httpdisk-{{gemver}}.gem"

#
# util
#

set quiet

banner +args:
  printf '\e[38;5;231;48;2;64;160;43;m{{BOLD}}[%s] %-72s {{NORMAL}}\n' "$(date +%H:%M:%S)" "{{args}}"

check-git-status:
  if [ ! -z "$(git status --porcelain)" ]; then echo "git status is dirty, bailing."; exit 1; fi
