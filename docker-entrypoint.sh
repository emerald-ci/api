#!/bin/bash
set -e

sleep 5
case $1 in
  api)
    bundle exec rake db:migrate
    bundle exec puma -b tcp://0.0.0.0:5000
    ;;
  worker)
    bundle exec sidekiq -r ./lib/emerald/api/workers/job_worker.rb
    ;;
esac

