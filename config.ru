#\ -s puma
require './config/environment'
require 'emerald/api'
run Emerald::API::App

