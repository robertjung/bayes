require 'redis/connection/hiredis'
require 'redis'
require 'digest/md5'

Dir[File.dirname(__FILE__) + '/bayes/*.rb'].each { |file| require file }

module Bayes
  def self.c
    bc = Bayes::Classifier.new 'test', filter_size: 2**17, weight: 1.0, ap: 0.5
  end
end
