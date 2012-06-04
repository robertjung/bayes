require ::File.expand_path('../spec_helper.rb', __FILE__)

module Bayes
  describe "Scope" do
    let(:name) { 'test' }
    let(:r) { MockRedis.new }
    let(:filter_size) { 2**17 }
    let(:options) { {} }
    let(:feature) { 'wurst' }

    subject {Scope.new name, r, options}

    describe "new scope" do
      it "should call 'create'" do
        Scope.any_instance.should_receive(:create).with(options)
        Scope.any_instance.should_not_receive(:get)
        subject
      end

      it "should set default parameters" do
        Bayes::BloomHelper.should_receive(:new).with(filter_size)
        subject.name.should == name
        subject.r.should == r
        subject.filter_size.should == filter_size
        subject.weight.should == 1.0
        subject.ap.should == 0.5
        subject.key.should == "S:#{subject.user}:#{subject.name}"
      end

      it "should create a dataset" do
        subject.r.hgetall(subject.key).should == {
          "ap" => "0.5",
          "filter_size" => filter_size.to_s,
          "weight" => "1.0"
        }
      end
    end

    describe "load scope" do
      before(:each) do
        Scope.new(name, r, {})
      end

      it "should call 'get'" do
        Scope.any_instance.should_receive(:get).with(options)
        Scope.any_instance.should_not_receive(:create)
        subject
      end

      it "should set default parameters" do
        Bayes::BloomHelper.should_receive(:new).with(filter_size)
        subject.name.should == name
        subject.r.should == r
        subject.filter_size.should == filter_size
        subject.weight.should == 1.0
        subject.ap.should == 0.5
        subject.key.should == "S:#{subject.user}:#{subject.name}"
      end

      it "should create a dataset" do
        subject.r.hgetall(subject.key).should == {
          "ap" => "0.5",
          "filter_size" => filter_size.to_s,
          "weight" => "1.0"
        }
      end
    end

    describe "#find_category" do
      let(:category_name) { 'a_category' }
      context "No categories present" do
        it "should return a new category with the corresponding name" do
          subject.categories.count.should == 0
          subject.find_category(category_name).class.should == Bayes::Category
          subject.find_category(category_name).name.should == category_name
        end
      end

      context "Searched category is present" do
        it "should return a new category with the corresponding name" do
          category = Category.new(subject, category_name, 0.0)
          subject.categories << category
          subject.categories.count.should == 1
          subject.find_category(category_name).should == category
        end
      end
    end

    describe "#total_feature_count" do
      it "should sum up all categories values" do
          Category.any_instance.stub(:feature_count).and_return(1)
          category = Category.new(subject, 'a', 1.0)
          subject.categories << category
          category = Category.new(subject, 'b', 1.0)
          subject.categories << category
          subject.total_feature_count(feature).should == 2
      end
    end

    describe "indexes" do
      it "should call bloomhelper's indexes method" do
        BloomHelper.any_instance.should_receive(:indexes).with(feature)
        subject.indexes(feature)
      end
    end

    describe "get" do
      before(:each) { Scope.new(name, r, {}) }

      it "should assign data to instance variables" do
        subject
        subject.weight.should == subject.data["weight"].to_f
        subject.ap.should == subject.data["ap"].to_f
        subject.filter_size.should == subject.data["filter_size"].to_i
      end

      context "with options" do
        let(:options) { { weight: 2.0, ap: 0.333, filter_size: 12345} }

        it "should assign correct options to instance variables" do
          subject
          subject.weight.should == options[:weight]
          subject.ap.should == options[:ap]
          # DON'T change filter_size!
          subject.filter_size.should == subject.data["filter_size"].to_i
        end
      end

      it "should load categories" do
        Scope.any_instance.should_receive(:load_categories).with(subject.data)
      end
    end

    describe "create" do
      let(:options) { { weight: 2.0, ap: 0.333, filter_size: 12345} }
      it "should assign data to instance variables" do
        subject
        subject.weight.should == options[:weight]
        subject.ap.should == options[:ap]
        subject.filter_size.should == options[:filter_size]
      end

      it "should call save" do
        Scope.any_instance.should_receive(:save)
        subject
      end
    end

    describe "#save" do
      it "should store to redis with correct data" do
        MockRedis.any_instance.should_receive(:hmset).
          with(subject.key, anything)
        subject
      end
    end

    describe "#load_categories" do
      before(:each) do
        s = Scope.new(name, r, {})
        s.r.hmset subject.key, "C:abc", 1, "C:bcd", 2
      end

      it "should fill categories attribute" do
        subject.send :load_categories
        subject.categories.count.should == 2
        subject.categories.each do |category|
          category.class.should == Bayes::Category
        end
      end
    end

    describe "#sum_categories" do
      before(:each) do
        s = Scope.new(name, r, {})
        s.r.hmset subject.key, "C:abc", 1, "C:bcd", 2
      end

      it "should fill categories attribute" do
        # subject.categories.size.should == 2
        subject.send :load_categories
        subject.send(:sum_categories).should == 3
      end
    end
  end
end
