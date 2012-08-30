module Bayes
  class Scope
    BLOOMSIZE = 2**17
    attr_accessor :filter_size, :categories, :categories_total, :weight, :ap, :r, :name, :user, :data, :key

    def initialize(name, r, options = {})
      @name = name
      @user = "default_user"
      @key = "S:#{@user}:#{@name}"
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
      @weight = options[:weight] || data["weight"].to_f
      @ap = options[:ap] || data["ap"].to_f
      @filter_size = data["filter_size"].to_i

      load_categories data
      @categories_total = sum_categories
    end

    def create(options = {})
      options = { :filter_size => BLOOMSIZE, :weight => 1.0, :ap => 0.5 }.merge options
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
      Hash[ data.select{ |k,v| k =~ /^C:.*/ }].each_pair{ |k,v| @categories << Category.new(self, k.gsub(/C:/, ""), v.to_f) }
    end

    def sum_categories
      categories.inject(0.0) { |sum, category| sum += category.value }
    end
  end
end
