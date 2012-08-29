# -*- encoding: utf-8 -*-
require File.expand_path('../lib/bayes/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Robert Jung"]
  gem.email         = ["rjung@mindslam.de"]
  gem.description   = %q{Bayes classifier built on counting bloomfilters stored in redis}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "bayes"
  gem.require_paths = ["lib"]
  gem.version       = Bayes::VERSION

  s.add_dependency "hiredis"
  s.add_dependency "redis"
  s.add_dependency "rake"
  s.add_dependency "nokogiri"

  s.add_test_dependency "rspec"
  s.add_test_dependency "mock_redis"
end
