require 'redis/connection/hiredis'
require 'redis'
require 'digest/md5'

class Classifier

  attr_accessor :scope, :filter_size, :categories, :categories_total, :weight, :ap, :r

  BLOOMSIZE = 2**24

  ########################
  # init

  def initialize(scope, options = {filter_size: BLOOMSIZE, weight: 1.0, ap: 0.5})
    @r = Redis.new(host: "localhost", port: 6379)
    @scope = scope

    scope_data = @r.hgetall(scope_key)

    @weight = scope_data["weight"].to_f || options["weight"]
    @ap = scope_data["ap"].to_f || options["ap"]
    @filter_size = scope_data["filter_size"].to_i || options[:filter_size]
    @categories = {}
    scope_data.select{ |k,v| k =~ /^C:.*/ }.each_pair{|k,v| @categories[k.gsub(/C:/, "")] = v.to_i }
    @categories_total = categories.inject(0) { |sum, hash| sum += hash[1] }
  end

  def save
    @r.hmset scope_key, "filter_size", @filter_size, "weight", weight, "ap", ap
  end

  #########################
  # train

  def untrain_phrase(phrase, categories)
    # train_phrase(phrase, categories)
  end

  def train_phrase(phrase, categories)
    train(phrase_to_features(phrase), categories)
  end

  def train(features, categories)
    categories.each do |category|
      features.each { |feature| update_feature(feature, category) }
      update_category(category)
    end
  end

  ###########################
  # access bloom filter data

  def update_feature(feature, category)
    indexes(feature).each { |index| update_index(category, index) }
  end

  def indexes(feature)
    [ feature, feature+"2", feature+"3"].  map { |hash_feature|
        Digest::MD5.hexdigest(hash_feature).to_i(16)
      }.map { |index| index % @filter_size }
  end

  def update_index(category, index)
    oldvalue = @r.getrange(category, index, index)
    value = 1
    value = oldvalue.getbyte(0) + 1 if oldvalue && oldvalue.length > 0
    @r.setrange(category_key(category), index, value.chr)
  end

  def update_category(category)
    @r.hincrby(scope_key, category_key(category), 1)
  end

  def feature_count(feature, category)
    # TODO: Add funky caching: tha would keep the calculation code way easier to understand.
    indexes(feature).map { |index|
      val = @r.getrange(category_key(category), index, index)
      val.length > 0 ? val.getbyte(0) : 0
    }.min
  end

  def total_feature_count feature
    @categories.inject(0) { |sum, category_array| sum += feature_count(feature, category_array[0]) }
  end

  #############################
  # Bayes - implementation

  def p_for_feature_in_category feature, category
    feature_count(feature, category) / categories[category].to_f
  end

  def p_for_feature_in_all_categories feature
    total_feature_count(feature) / categories_total.to_f
  end

  def p_for_feature feature, category
    p_total = p_for_feature_in_all_categories(feature)
    p_feature = p_for_feature_in_category(feature, category)

    ((weight * ap) + (p_total * p_feature)) / (weight + p_total)
  end

  def p_for_category features, category

    ps = features.map { |feature| p_for_feature(feature, category) }
    p_for_all_features = ps.inject(1.0) { |prod, p| prod *= p }
    inverse_p_for_all_features = ps.inject(1.0) { |prod, p| prod *= (1.0 - p) }

    p_for_all_features / (p_for_all_features + inverse_p_for_all_features)
  end

  def p_for_all features
    result = {}
    @categories.each do |category_array|
      result[category_array[0]] = p_for_category(features, category_array[0])
    end
    result
  end

  def result phrase
    features = phrase_to_features(phrase)
    p_for_all(features)
  end

private
  def scope_key
    "S:#{scope}"
  end

  def category_key category
    "C:#{category}"
  end

  def bloom_key category
    "B:#{scope}:#{category}"
  end

  def phrase_to_features(phrase)
    phrase.unpack('C*').pack('U*').gsub(/[^\w]/, " ").split.inject([]){|data, w| data << w.downcase}.uniq
  end
end

def c
  bc = Classifier.new 'test'
end
