require 'sinatra'
require 'sinatra/namespace'
require 'redis'
require 'json'

get '/' do
	redirect '/api/v1/'
end

namespace '/api/v1' do
	before do
		content_type 'application/json'
	end

	get '/' do

		'Hi, I''m Frank Sinatra API - API Details: +  "/api/v1/partners" - Get all partners from all countries and location  + "/api/v1/partners?country={0}" - Get all partners from specific country  + "/api/v1/partners?country={0}&location={1}" - Get all partners from specific country and specific location  +  "/api/v1/partners/{0} - Get all partners filtered by the given wildcard name  +  "/api/v1/locations - Get all locations with the parent country"'		
	end 

	get '/partners' do
		@redis = Redis.new(host: "127.0.0.1", port: 6379)
		if params[:country].nil?
			partners = @redis.smembers('partners_all')
		else
			if params[:location].nil?
				partners = @redis.smembers('partners_' + params[:country].downcase)				
			else
				partners = @redis.smembers('partners_' + params[:country].downcase + '_' + params[:location].downcase)
			end
		end
		partners.to_json
	end

	get '/partners/:wildcard' do | wildcard |
		@redis = Redis.new(host: "127.0.0.1", port: 6379)
		ret_partners = []
		partners = @redis.smembers('partners_all')
		partners.each do | partner |
			if partner.include? wildcard
				ret_partners << partner
			end
		end
		ret_partners.to_json
	end

	get '/locations' do
		@redis = Redis.new(host: "127.0.0.1", port: 6379)
		locations = @redis.smembers('locations_all')
		locations.to_json
	end

end
