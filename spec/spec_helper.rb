require 'rubygems'
require 'bundler/setup'

RSpec.configure do |c|
  c.mock_with :rspec
  c.color_enabled = true
  c.order = :random
  c.include(RSpec::Mocks::Methods)
  c.before(:each) { Redis.stub_calls! }
end

$: << ::File.expand_path('../../', __FILE__)

require 'redis'
require 'mock_redis'
require 'bayes'

class Redis
  def self.stub_calls!
    stub!(:new).and_return(MockRedis.new)
  end
end


