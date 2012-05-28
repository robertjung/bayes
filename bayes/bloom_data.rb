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

        new_value = val.length > 0 ? val.getbyte(0) : 0
        break if new_value.nil? || new_value <= 0

        old_value = new_value if old_value.nil? || old_value < new_value
      end
      old_value || 0
    end

    # TODO: "de-compress"
    def get_at_index(index)
      @r.getrange(key, index, index)
    end

    # yeah, i know there is a race condition :/ guess this could be addressed by a "training-queue"
    # TODO: "compress"
    def update_at_index(index, by=1)
      oldvalue = get_at_index(index)
      value = by
      value = oldvalue.getbyte(0) + by if oldvalue && oldvalue.length > 0
      @r.setrange(@key, index, value.chr)
    end
  end
end
