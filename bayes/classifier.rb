require 'nokogiri'
require 'set'

module Bayes
  class Classifier

    attr_accessor :scope, :r

    def initialize(scope_name, options = {})
      @r = Redis.new(host: "localhost", port: 6379)
      @scope = Scope.new(scope_name, @r, options)
    end

    def train_phrase(phrase, category_names)
      features = phrase_to_features(phrase)
      train_features features, category_names
    end

    def train_xliff(file, category_names)
      features = xliff_to_features(file)
      train_features features, category_names
    end

    def train_file file, category_names
      features = phrase_to_features(File.read(file))
      train_features features, category_names
    end

    def convert_and_train_file file, category_names
      xliff = `/Users/rjung/Downloads/okapi-apps_cocoa-macosx-x86_64_0.16/tikal.sh -x #{file} |grep "Output: " | awk {'print $2'} `
      train_xliff xliff, category_names
    end

    def train_features features, category_names
      categories = Array(category_names).map { |cname| scope.find_category(cname) }
      categories.each { |category| category.train(features) }
    end

    def result_for_phrase phrase
      result phrase_to_features(phrase)
    end

    def result_for_file file
      result phrase_to_features(File.read(file))
    end

    def result_for_xliff file
      result xliff_to_features(file)
    end

    def convert_and_result_file file
      xliff = `cd /Users/rjung/Downloads/okapi-apps_cocoa-macosx-x86_64_0.16/; ./tikal.sh -x #{file} |grep "Output: " | awk {'print $2'} `
      result_for_xliff xliff
    end

    def result features
      result = {}
      scope.categories.each do |category|
        result[category.name] = Calculator.new(category, features).calculate
      end
      result
    end

  private

    # TODO
    # * different feature extraction methods?
    def xliff_to_features(file)
      doc = Nokogiri::XML(File.open(file))
      features = Set.new
      doc.css("source").each {|node| features.merge(extract(node.content)) }
      features
    end

    def phrase_to_features(phrase)
      # TODO: unpack/pack - hack still needed?
      extract phrase
    end

    def extract data
      features = Set.new
      data.unpack('C*').pack('U*').gsub(/[^\w]/, " ").split.each {|w| features.add w.downcase }
      features
    end
  end
end
