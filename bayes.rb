require  'redis/connection/hiredis'
require 'redis'

class Classifier

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
        @r.hincrby word, category, options[:weight]
      end
      @r.hincrby "CATEGORIES", category, options[:weight]
    end
  end

  def category_count category
    @r.hget("CATEGORIES", category).to_i
  end

  def categories_total
    @r.hvals("CATEGORIES").inject(0){|sum, val| sum += val.to_i}.to_f
  end

  def categories_total_for_word word
    @r.hvals(word).inject(0){|sum, val| sum += val.to_i}.to_f
  end

  def category_for_word(word, category)
    @r.hget(word, category).to_f
  end

  def word_prob word, category
    ccount = category_count(category)
    ccount > 0 ? category_for_word(word, category) / ccount : 0.0
  end

  def weighted_word_prob(word, category, options = {weight: 1.0, ap: 0.5})
    totals = categories_total_for_word word
    ((options[:weight]*options[:ap]) + (totals*word_prob(word, category))) / (options[:weight] + totals)
  end

  def docprob words, category
    words.inject(1.0){ |prod, word| prod *= weighted_word_prob(word, category) }
  end

  def bayes phrase, category
    (category_count(category) / categories_total) * docprob(phrase_to_words(phrase), category)
  end

  def result phrase
    @r.hkeys("CATEGORIES").each{|category|
      bayes phrase, category
    }
  end

##############################
  # now for real: ugly, but fast.

  def fast_result_for_word word_category_data, category, categories_data, totals
    weight, ap = 1.0, 0.5
    category_count = categories_data[category]
    return 0.0 unless category_count
    word_prob = word_category_data[category].to_f / category_count.to_f

    ((weight * ap) + (totals * word_prob)) / (weight + totals)
  end

  def fast_result phrase
    total_category_data = @r.hgetall "CATEGORIES"
    words = phrase_to_words(phrase)
    word_data = words.inject({}) { |wd, word| wd[word] = @r.hgetall(word); wd }

    data = {}
    total_category_data.each_key do |category|
      data[category] = words.inject(1.0) { |p, word| 
        totals = word_data[word].inject(0){|sum, val| sum += val[1].to_i}
        p *= fast_result_for_word(word_data[word], category, total_category_data, totals)
      }
    end

    total_category = total_category_data.inject(0){|sum, cat| sum += cat[1].to_i}
    total_category_data.each_key { |category|
      data[category] *= (total_category_data[category].to_f / total_category)
    }
    data
  end
end

c=Classifier.new
10.times { c.fast_result "buy you some viagra!" }
