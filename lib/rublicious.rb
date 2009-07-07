require 'pp'
require 'rubygems'
require 'httparty'

module Rublicious

  class Feeds
    attr_reader :xml_client, :json_client

    def initialize(xml_client = XMLClient.new, json_client = JSONClient.new)
      @xml_client, @json_client = xml_client, json_client
    end

    alias old_method_missing method_missing

    def method_missing(meth, *args)
      return @xml_client.send(meth, *args) if @xml_client.respond_to? meth
      return @json_client.send(meth, *args) if @json_client.respond_to? meth 
      
      old_method_missing meth, *args
    end
  end

  class Client
    include HTTParty

    def initialize
      @handlers = []
    end

    def get(*params)
      handle_response self.class.get(*params)
    end

    def add_response_handler(&block)
      @handlers << Proc.new(&block)
    end

    def handle_response(response)
      if @handlers.any?
        @handlers.each do |handler|
          response = handler.call(response)
        end
      end
      response
    end

    def default_handler(response)
      response.each do |item|
        meths = extract_method_names(item)
        meths.each do |method_name|
          add_method(item, method_name)
        end
      end
    end

    def query_string(tag, count)
      query = '' 
      query << '/' + tag if tag
      query << "?count=#{count}"
      query
    end

    def extract_method_names(response_sample, prefix = '')
      meths_array = []

      response_sample.keys.inject(meths_array) do |arr, key|
        method_name = prefix + key
        arr << method_name

        if response_sample[key].is_a?(Hash)
          arr << extract_methods(response_sample[key], method_name + '_')
        end
      end

      meths_array.flatten
    end

    def add_method(response_item, method_name)
      keys = method_name.split '_'

      puts "defining method #{method_name} on #{response_item.object_id}"
      response_item.instance_eval(%Q{
          def #{method_name}
            result = self
            while key = keys.pop
              result = result[key]
            end
            result
          end
        }
      )
    end

  end

  class XMLClient < Client
    base_uri 'http://feeds.delicious.com/v2/xml'
    format :xml

    def get_tagurls(*tags)
      count = 10
      get("/tag/#{tags.join('+')}?count=#{count}")
    end

    def get_popular(tag = nil, count = 5)
      get("/popular#{query_string(tag, count)}")
    end

    def get_userposts(user, tag = nil, count = 15)
      get("/#{user}/#{query_string(tag, count)}")
    end

    def get_urlposts(url)
      get("/url/#{Digest::MD5.hexdigest(url)}")
    end
  end

  class JSONClient < Client
    base_uri 'http://feeds.delicious.com/v2/json'
    format :json

    def get_urlinfo(url)
		  get("/urlinfo/#{Digest::MD5.hexdigest(url)}").first #will always return one result
	  end
  end
end

