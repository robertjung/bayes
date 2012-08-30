module Bayes
  class BloomData
    ###########################
    # access bloom filter data

    attr_accessor :r, :key, :scope
    def initialize(scope, key)
      @scope = scope
      @r = scope.r
      @key = key
      @cache = {}
    end

    def update_category(category_counter_key, by=1)
      @value = r.hincrby(scope.key, category_counter_key, by)
    end

    def update_feature(feature, by=1)
      scope.indexes(feature).each { |index| update_at_index(index, by) }
    end

    def feature_count(feature)
      @cache[feature] ||= get_indexes(feature)
    end

  private

    def get_indexes feature
      old_value = nil
      scope.indexes(feature).each do |index|
        val = get_at_index(index)
        val = decompress val
        break if val <= 0

        old_value = val if old_value.nil? || old_value < val
      end
      old_value || 0
    end

    def get_at_index(index)
      v = @r.getrange(key, index, index)
      (v && v.length > 0) ? v.bytes.to_a[0] : 0
    end

    # yeah, i know there is a race condition :/ guess this could be addressed by a "training-queue"
    def update_at_index(index, by=1)
      value = get_at_index(index)
      by = compress(value)
      if by != 0
        value = by + value
        @r.setrange(@key, index, value.chr)
      end
      value
    end

    def compress(current)
      return 0 if current >= 255
      chance = 12.645916636849323 / (1.01**current - 1.0)
      rand <= chance ? 1 : 0
    end

    def decompress(value)
      return 0 unless value && value.length > 0
      0.upto(value).inject(0){|sum, i| sum += (1.01**i) }.round.to_i
    end
  end
end
