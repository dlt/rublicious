require '../lib/rublicious.rb'

describe Rublicious::Client do
  before do
    @feeds = Rublicious::Client.new
  end

  it "should have a default handler that add methods based on the response hash keys" do
    rh = [{'a' => 1}]
    @feeds.default_handler rh
    rh.first.respond_to?('a').should be_true
  end

end
