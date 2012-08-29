require "bayes/version"
require 'redis/connection/hiredis'
require 'redis'
require 'digest/md5'

Dir[File.dirname(__FILE__) + '/bayes/*.rb'].each { |file| require file }

module Bayes
  # Your code goes here...
end
