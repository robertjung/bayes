require "bayes/version"
require 'redis/connection/hiredis'
require 'redis'
require 'digest/md5'

Dir[File.dirname(__FILE__) + '/bayes/*.rb'].reject{|file| file == "version.rb"}.each { |file| require file }

module Bayes
  # Your code goes here...
end
