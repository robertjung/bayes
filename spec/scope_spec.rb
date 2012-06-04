require ::File.expand_path('../spec_helper.rb', __FILE__)

module Bayes
  describe "Scope" do
    let(:name) { 'test' }
    let(:r) { MockRedis.new }

    subject {Scope.new name, r}

    describe "new scope" do
      it "should set default parameters" do
        subject.name.should == name
        subject.r.should == r
        subject.filter_size.should == 2**17
        subject.weight.should == 1.0
        subject.ap.should == 0.5
        subject.key.should == "S:#{subject.user}:#{subject.name}"
      end

      it "should create a dataset" do
        subject.r.hgetall(subject.key).should == {
          "ap" => "0.5",
          "filter_size" => "131072",
          "weight" => "1.0"
        }
      end
    end

    describe "load scope"
    describe "#find_category"
    describe "total_feature_count"
    describe "indexes"
    describe "get"
    describe "create"
    describe "save"
    describe "load_categories"
    describe "sum_categories"
  end
end
