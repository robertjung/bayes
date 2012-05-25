require 'redis/connection/hiredis'
require 'redis'
require 'digest/md5'

class Classifier

  attr_accessor :scope, :filter_size, :categories, :categories_total, :weight, :ap

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
    train_phrase(phrase, categories)
  end

  def train_phrase(phrase, categories)
    train(phrase_to_words(phrase), categories)
  end

  def train(words, categories)
    categories.each do |category|
      words.each { |word| update_word(word, category) }
      update_category(category)
    end
  end

  ###########################
  # access bloom filter data

  def update_word(word, category)
    indexes(word).each { |index| update_index(category, index) }
  end

  def indexes(word)
    [ word, word+"2", word+"3"].map { |word|
      Digest::MD5.hexdigest(word).to_i(16)
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

  def get_wordcount(category, word)
    indexes(word).map { |index|
      val = @r.getrange(category, index, index)
      val.length > 0 ? val.getbyte(0) : 0
    }.min
  end

  #############################
  # BLOOMfilter - implementation

  def bloom_result_for_word(word_count, category_count, totals)
    return 0.0 unless category_count
    word_prob = word_count.to_f / category_count.to_f

    ((weight * ap) + (totals * word_prob)) / (weight + totals)
  end

  def bloom_result(phrase)
    words = phrase_to_words(phrase)

    totals = Hash.new(0.0)
    word_counts = {}
    data = {}

    @categories.each_key do |category|
      word_counts[category] = Hash.new(0.0)
      words.each { |word|
        word_counts[category][word] = get_wordcount(category, word)
        totals[word] += word_counts[category][word]
      }
    end

    @categories.each_key do |category|
      data[category] = words.inject(1.0) { |p, word|
        p *= bloom_result_for_word(word_counts[category][word], categories[category], totals[word])
      }
      data[category] *= (categories / categories_total)
    end

    # normalize
    max = data.values.max
    max = 1.0/max
    data.each_pair { |category, rank| data[category] *= max }
    data
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

  def phrase_to_words(phrase)
    phrase.unpack('C*').pack('U*').gsub(/[^\w]/, " ").split.inject([]){|data, w| data << w.downcase}.uniq
  end
end
