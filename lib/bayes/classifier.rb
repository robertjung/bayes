module Bayes
  class Classifier

    attr_accessor :scope, :r

    def initialize(scope_name, options = {})
      @r = Redis.new(:host => "localhost", :port => 6379)
      @scope = Scope.new(scope_name, @r, options)
    end

    def train_phrase(phrase, category_names)
      features = phrase_to_features(phrase)
      categories = Array(category_names).map { |cname| scope.find_category(cname) }

      categories.each { |category| category.train(features) }
    end

    def result phrase
      features = phrase_to_features(phrase)

      result = {}
      {}.tap do |result|
        scope.categories.each do |category|
          result[category.name] = Calculator.new(category, features).calculate
        end
      end
    end

    def best phrase, minimal_difference = 1.1
      r = result(phrase)
      sorted = r.sort {|a,b| b[1]<=>a[1]}
      (sorted[0][1] >= (sorted[1][1] * minimal_difference)) ? sorted[0][0] : nil
    end

  private

    # TODO
    # * different feature extraction methods?

    def phrase_to_features(phrase)
      # TODO: unpack/pack - hack still needed?
      # TODO: Umlaute & shit
      phrase.unpack('C*').pack('U*').gsub(/[^\w]/, " ").split.inject([]){|data, w| data << w.downcase}.uniq
    end
  end
end
