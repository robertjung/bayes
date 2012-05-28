require 'redis/connection/hiredis'
require 'redis'
require 'digest/md5'

module Bayes

  class Classifier

    attr_accessor :scope, :r

    def initialize(scope_name, options = {})
      @r = Redis.new(host: "localhost", port: 6379)
      @scope = Scope.new(scope_name, @r, options)
    end

    def train_phrase(phrase, category_names)
      features = phrase_to_features(phrase)
      categories = Array(category_names).map { |cname| scope.find_category(cname) }

      categories.each { |category| category.train(features) }
    end

    def result phrase
      features = phrase_to_features(phrase)
      p_for_all(features)
    end

    def p_for_all features
      result = {}
      scope.categories.each do |category|
        result[category.name] = Calculator.new(category, features).calculate
      end
      result
    end

  private

    def phrase_to_features(phrase)
      # TODO: unpack/pack - hack still needed?
      phrase.unpack('C*').pack('U*').gsub(/[^\w]/, " ").split.inject([]){|data, w| data << w.downcase}.uniq
    end
  end


  class Scope
    BLOOMSIZE = 2**17
    attr_accessor :filter_size, :categories, :categories_total, :weight, :ap, :r, :name, :user, :data, :key

    def initialize(name, r, options = {})
      @name = name
      @user = "default_user"
      @key = "S:#{user}:#{name}"
      @r = r
      @categories = []
      @categories_total = 0.0

      @data = r.hgetall(key)

      if data.empty?
        create(options)
      else
        get(options)
      end

      @bloom_helper = BloomHelper.new(filter_size)
    end

    def find_category(name)
      category = @categories.select { |c| c.name == name }.first || Category.new(self, name, 0)
    end


    def total_feature_count feature
      categories.inject(0) { |sum, category| sum += category.feature_count(feature) }
    end

    def indexes(feature)
      @bloom_helper.indexes(feature)
    end

  private

    def get(options)
      @weight = options["weight"] || data["weight"].to_f
      @ap = options["ap"] || data["ap"].to_f
      @filter_size = data["filter_size"].to_i

      load_categories data
      @categories_total = sum_categories
    end

    def create(options = {filter_size: BLOOMSIZE, weight: 1.0, ap: 0.5})
      @weight = options[:weight]
      @ap = options[:ap]
      @filter_size = options[:filter_size]

      save
    end

    def save
      @r.hmset(key,
               "filter_size", @filter_size,
               "weight", @weight,
               "ap", @ap)
    end

    def load_categories scope_data
      data.select{ |k,v| k =~ /^C:.*/ }.each_pair{ |k,v| @categories << Category.new(self, k.gsub(/C:/, ""), v.to_f) }
    end

    def sum_categories
      categories.inject(0.0) { |sum, category| sum += category.value }
    end
  end



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

    def calculate
      ps = features.map { |feature| p_for_feature(feature) }
      p_for_all_features = ps.inject(1.0) { |prod, p| prod *= p }
      inverse_p_for_all_features = ps.inject(1.0) { |prod, p| prod *= (1.0 - p) }

      p_for_all_features / (p_for_all_features + inverse_p_for_all_features)
    end
  end


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

    def update_category(by=1)
      data.update_category(@category_counter_key, by)
    end

    def update_feature(feature, by=1)
      data.update_feature(feature, by)
    end

    def feature_count(feature)
      data.feature_count(feature)
    end

    def train(features)
      features.each { |feature| update_feature(feature, 1) }
      update_category(1)
    end
  end



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

    # yeah, i know there is a race condition :/
    # TODO: "compress"
    def update_at_index(index, by=1)
      oldvalue = get_at_index(index)
      value = by
      value = oldvalue.getbyte(0) + by if oldvalue && oldvalue.length > 0
      @r.setrange(@key, index, value.chr)
    end
  end


  class BloomHelper
    attr_accessor :filter_size

    def initialize(filter_size)
      @filter_size = filter_size
      @cache = {}
    end

    def hash(value)
      Digest::MD5.hexdigest(value).to_i(16)
    end

    def index(hash)
      hash % filter_size
    end

    def calculate(feature)
      [ feature, feature+"2", feature+"3"].map { |hash_feature| index(hash(hash_feature)) }
    end

    def indexes(feature)
      @cache[feature] ||= calculate(feature)
    end
  end
end

def c
  bc = Bayes::Classifier.new 'test', filter_size: 2**17, weight: 1.0, ap: 0.5
end
