module Bayes
  class BloomHelper
    attr_accessor :filter_size

    def initialize(filter_size)
      @filter_size = filter_size
      @cache = {}
    end

    def hash(value)
      Digest::MD5.hexdigest(value).to_i(16)
    end

    def index(hash)
      hash % filter_size
    end

    def calculate(feature)
      [ feature, feature+"2", feature+"3"].map { |hash_feature| index(hash(hash_feature)) }
    end

    def indexes(feature)
      @cache[feature] ||= calculate(feature)
    end
  end
end
