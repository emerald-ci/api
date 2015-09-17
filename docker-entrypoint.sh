#!/bin/bash
set -e

sleep 5
bundle exec rake db:migrate
bundle exec puma -b tcp://0.0.0.0:5000

