require ::File.expand_path('../spec_helper.rb', __FILE__)

module Bayes
  describe "Classifier" do

    subject { Classifier.new(scopename, options) }
    let(:scopename) { 'test' }
    let(:options) { { filter_size: 2**17, weight: 1.0, ap: 0.5 } }

    describe "creation" do
      it "should create a Redis client object" do
        subject.r.class.should == MockRedis
      end

      it "should instanciate a Scope object" do
        Scope.should_receive(:new).with(scopename, subject.r, options)
        subject
      end

      it "should assign Redis connection" do
        subject.scope.class.should == Scope
        subject.scope.r.should == subject.r
      end
    end

    describe "#train_phrase" do
      let(:phrase) { "This is a test. A wonderful test!" }
      let(:category) { "Spam" }

      it "should extract features from given phrase" do
        subject.should_receive(:phrase_to_features).with(phrase).and_return ["das", "ist"]
        subject.train_phrase phrase, category
      end

      context "one category as string" do
        it "should try to find category" do
          Scope.any_instance.should_receive(:find_category).with(category).
            and_return Category.new subject.scope, 2,3
          subject.train_phrase phrase, category
        end
      end

      context "several categories as array" do
        let(:category) { ["Cat1", "Cat2"] }

        it "should try to find category" do
          Scope.any_instance.should_receive(:find_category).
            twice.and_return Category.new subject.scope, 2,3
          subject.train_phrase phrase, category
        end
      end
    end

    describe "#result" do
      let(:phrase) { "This is a test. A wonderful test!" }
      let(:category) { "Spam" }

      it "should extract features from given phrase" do
        subject.should_receive(:phrase_to_features).with(phrase).and_return ["das", "ist"]
        subject.result phrase
      end

      it "should calculate rankings for all categories" do
        pending "Many many test with real data? or somewhere else?"
      end
    end

    describe "#phrase_to_features"
  end
end
