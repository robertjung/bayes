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
      return -1.0 if n_c <= 0

      s = scope.weight.to_f
      n = scope.total_feature_count(feature)

      ((s * p) + ( n * (n_c / value))) / (s + n)
    end

    def p_for_feature feature
      p_cat = p_for_feature_in_category(feature)
      p_total = scope.categories.inject(0.0) { |sum, c| sum += c.p_for_feature_in_category(feature) }

      return nil unless p_cat >= 0.0 && p_total >= 0.0

      result = p_cat / p_total
      [[0.0, result].max, 1.0].min
    end

    def feature_count(feature)
      data.feature_count(feature)
    end

  private

    def p
      @p ||= self.value / scope.categories_total
    end

    def update_category(by=1)
      data.update_category(@category_counter_key, by)
    end

    def update_feature(feature, by=1)
      data.update_feature(feature, by)
    end
  end
end
