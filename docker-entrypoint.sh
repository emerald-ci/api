#!/bin/bash
set -e

case $1 in
  api)
    ./script/wait_for_dependencies.sh
    bundle exec rake db:migrate
    bundle exec puma -b tcp://0.0.0.0:5000
    ;;
  worker)
    ./script/wait_for_dependencies.sh
    bundle exec sidekiq -r ./config/worker_environment.rb
    ;;
  migrate)
    ./script/wait_for_dependencies.sh
    bundle exec rake db:migrate
    ;;
  seed)
    ./script/wait_for_dependencies.sh
    bundle exec rake db:seed
    ;;
  rspec)
    ./script/wait_for_dependencies.sh
    bundle exec rake db:migrate
    bundle exec rspec ${@:2} # allow handing arguments
    ;;
  bash)
    /bin/bash
    ;;
esac

