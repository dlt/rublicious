require '../lib/rublicious.rb'

describe Rublicious::Client do
  before do
    @feeds = Rublicious::Client.new
    @response = [{'a' => 1, 'b' => 2}, {'b' => {'c' => {'d' => 10}}}]
    @resp_hash = {'rss' => 'items', 'links' => ['www.google.com', 'www.google.com.br', 'a string']}
  end

  it "should have a default handler that add methods based on the response hash keys" do
    @feeds.default_handler @response
    @response.first.respond_to?('a').should be_true
    @response.first.respond_to?('c').should be_false

    @response[1].respond_to?('b').should be_true
    @response[1].respond_to?('b_c').should be_true
    @response[1].respond_to?('b_c_d').should be_true
    @response[1].respond_to?('c_d').should be_false
    @response[1].respond_to?('b_d').should be_false

    @feeds.default_handler @resp_hash
    @resp_hash.respond_to?('rss').should be_true
  end

  it "should have metaprogrammed methods to get hash values" do
    @feeds.default_handler @response
    @response.first.respond_to?('a').should be_true
    @response.first.a.should == 1
    @response.first.b.should == 2
    @response[1].b_c_d.should == 10

    @feeds.default_handler @resp_hash
    @resp_hash.rss.should == 'items'
    @resp_hash.links.should include('a string')
  end

end
