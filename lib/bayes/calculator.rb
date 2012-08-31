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
      ps = features.map { |feature| category.p_for_feature(feature) }.compact

      # calculate in log domain to avoid floating point underflows
      n = ps.inject(0.0) {|sum, p| sum += Math::log(1.0-p) - Math::log(p) }
      1.0 / ( 1.0 + Math::E**n)
    end
  end
end
