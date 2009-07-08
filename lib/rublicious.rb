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
    def initialize
      @handlers = []
    end

    def add_response_handler(&block)
      @handlers << Proc.new(&block)
    end

    def handle_response(response)
      default_handler response
      if @handlers.any?
        @handlers.each do |handler|
          response = handler.call(response)
        end
      end
      response
    end

    def default_handler(response)
      extract_hash_method_names response if response.is_a? Hash
      extract_array_method_names response if response.is_a? Array
    end

    private
    def get(*params)
      handle_response self.class.get(*params)
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
        method_name.gsub!(':', '_')
        arr << method_name

        value = response_sample[key]
        if value.is_a?(Hash)
          arr << extract_hash_method_names(value, method_name + '_')
        elsif value.is_a?(Array) && all_items_are_hashes(value)
          arr << extract_array_method_names(value, method_name + '_')
        end

        meths_array
      end

      meths_array.flatten
    end

    def extract_hash_method_names(hash, prefix = '')
      meths = extract_method_names(hash, prefix)
      meths.each do |method_name|
        add_method(hash, method_name)
      end
    end

    def extract_array_method_names(array, prefix = '')
      array.each {|item| extract_hash_method_names(item, prefix)}
    end

    def add_method(response_item, method_name)
      keys = method_name.split '_'
      method = method_string(method_name, keys)
      response_item.instance_eval method
    end
   

    def all_items_are_hashes(array)
      array.each do |item|
        return false unless item.is_a? Hash
      end
      return true
    end

    def method_string(method_name, keys)
      hash_accessor = hash_keys_as_string(keys)
      %Q{
        def #{method_name}
          self#{hash_accessor}
        end
      }
    end

    def hash_keys_as_string(keys)
      keys.map {|k| "['#{k}']"}.join
    end
  end

  class XMLClient < Client
    include HTTParty
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
    include HTTParty
    base_uri 'http://feeds.delicious.com/v2/json'
    format :json

    def get_urlinfo(url)
		  get("/urlinfo/#{Digest::MD5.hexdigest(url)}").first #will always return one result
	  end
  end
end

