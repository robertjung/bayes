module Bayes
  class Calculator
    #############################
    # Bayes - implementation
    #
    attr_accessor :features, :category, :scope

    def initialize(category, features)
      @scope = category.scope
      @category = category
      @features = features
    end

    def calculate
      ps = features.map { |feature| p_for_feature(feature) }
      p_for_all_features = ps.inject(1.0) { |prod, p| prod *= p }
      inverse_p_for_all_features = ps.inject(1.0) { |prod, p| prod *= (1.0 - p) }

      p_for_all_features / (p_for_all_features + inverse_p_for_all_features)
    end

  private

    def p_for_feature_in_category feature
      category.feature_count(feature) / category.value
    end

    def p_for_feature_in_all_categories feature
      scope.total_feature_count(feature) / scope.categories_total
    end

    def p_for_feature feature
      p_total = p_for_feature_in_all_categories(feature)
      p_feature = p_for_feature_in_category(feature)

      ((scope.weight * scope.ap) + (p_total * p_feature)) / (scope.weight + p_total)
    end
  end
end
