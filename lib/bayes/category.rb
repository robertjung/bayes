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

    def p_for_feature_in_category feature
      n_c = feature_count(feature)
      s = 0.0 #scope.weight.to_f
      n = 1.0 #scope.total_feature_count(feature)

      result = ((s * p_c) + ( n * (n_c / value))) / (s + n)
    end

    def p_for_feature feature
      p_cat = p_c * p_for_feature_in_category(feature)
      p_total = scope.categories.inject(0.0) { |sum, c|
        sum += (c.p_c * c.p_for_feature_in_category(feature))
      }

      return nil if p_cat.nil? || p_total <= 0.0

      result = p_cat / p_total
      result = [[0.0, result].max, 1.0].min
      return nil if result < 0.6 && result > 0.4

      result
    end

    def feature_count(feature)
      data.feature_count(feature)
    end

    def p_c
      @p ||= self.value / scope.categories_total
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
