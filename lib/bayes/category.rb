module Bayes
  class Category
    attr_accessor :name, :scope, :value, :data

    def initialize(scope, name, value)
      @scope = scope
      @r = scope.r
      @name = name
      @category_counter_key = "C:#{name}"
      @category_key = "C:#{scope.user}:#{scope.key}:#{name}"
      @value = value
      @data = BloomData.new(scope, @category_key)
    end

    def train(features)
      features.each { |feature| update_feature(feature, 1) }
      update_category(1)
    end

    def feature_count(feature)
      data.feature_count(feature)
    end

  private

    def update_category(by=1)
      data.update_category(@category_counter_key, by)
    end

    def update_feature(feature, by=1)
      data.update_feature(feature, by)
    end
  end
end
