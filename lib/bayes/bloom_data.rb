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

        new_value = val.length > 0 ? val.bytes.to_a[0] : 0
        break if new_value.nil? || new_value <= 0

        old_value = new_value if old_value.nil? || old_value < new_value
      end
      old_value || 0
    end

    def get_at_index(index)
      v = @r.getrange(key, index, index)
      decompress v
    end

    # yeah, i know there is a race condition :/ guess this could be addressed by a "training-queue"
    def update_at_index(index, by=1)
      oldvalue = get_at_index(index)
      by = compress(by)
      value = by + ((oldvalue && oldvalue.length > 0) ?  oldvalue.bytes.to_a[0] : 0 )
      @r.setrange(@key, index, value.chr)
    end

    def compress(current)
      return 0 if current >= 255
      chance = 12.645916636849323 / (1.01**current - 1.0)
      rand >= chance ? 1 : 0
    end

    def decompress(value)
      0.upto(value).inject(0){|sum, i| sum += (1.01**i) }.round
    end
  end
end
