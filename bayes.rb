require 'redis/connection/hiredis'
require 'redis'
require 'digest/md5'

class Classifier

  BLOOMSIZE = 2**24

  def initialize
    @r = Redis.new(host: "localhost", port: 6379)
  end

  def phrase_to_words(phrase)
    phrase.unpack('C*').pack('U*').gsub(/[^\w]/, " ").split.inject([]){|data, w| data << w.downcase}.uniq
  end

  def untrain_phrase phrase, categories
    train_phrase phrase, categories, { weight: 1 }
  end

  def train_phrase phrase, categories, options = { weight: 1 }
    train phrase_to_words(phrase), categories
  end

  def train words, categories, options = { weight: 1 }
    categories.each do |category|
      words.each do |word|
        indexes(word).each do |index|
          update_index category, index
        end
      end
      @r.hincrby "CATEGORIES", category, options[:weight]
    end
  end

  def indexes(word)
    [ word, word+"2", word+"3"].map{|word| Digest::MD5.hexdigest(word).to_i(16) }.map{|index| index % BLOOMSIZE}
  end

  def update_index(category, index)
    oldvalue = @r.getrange(category, index, index)
    value = 1
    value = oldvalue.getbyte(0) + 1 if oldvalue && oldvalue.length > 0
    @r.setrange category, index, value.chr
  end

#############################
  # BLOOMfilter - implementation 1
  #
  def bloom_get_wordcount(category, word)
    indexes(word).map { |index|
      val = @r.getrange(category, index, index)
      val.length > 0 ? val.getbyte(0) : 0
    }.min
  end

  def bloom_result_for_word word_count, category_count, totals
    weight, ap = 1.0, 0.5
    return 0.0 unless category_count
    word_prob = word_count.to_f / category_count.to_f

    ((weight * ap) + (totals * word_prob)) / (weight + totals)
  end

  def bloom_result phrase
    total_category_data = @r.hgetall "CATEGORIES"
    words = phrase_to_words(phrase)

    totals = Hash.new(0.0)
    word_counts = {}
    data = {}

    total_category_data.each_key do |category|
      word_counts[category] = Hash.new(0.0)
      words.each { |word|
        word_counts[category][word] = bloom_get_wordcount(category, word)
        totals[word] += word_counts[category][word]
      }
    end

    total_category_data.each_key do |category|
      data[category] = words.inject(1.0) { |p, word|
        p *= bloom_result_for_word(word_counts[category][word], total_category_data[category], totals[word])
      }
    end
    max = data.values.max
    max = 1.0/max
    data.each_pair { |category, rank| data[category] *= max }
    data
  end
end
