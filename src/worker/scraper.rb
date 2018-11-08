require 'nokogiri'
require 'httparty'
require 'byebug'
require 'geocoder'
require 'redis'
require 'json'
require 'csv'

#settings
$partner_locations = []
$partner_list = []
$url = "CHANGE_FOR_PRIVACY"
$atoz = [*'a'..'z', '0-10']

#objects
class Array
  def self.wrap(object)
    if object.nil?
      []
    elsif object.respond_to?(:to_ary)
      object.to_ary || [object]
    else
      [object]
    end
  end
end

class Location
	def initialize(name, url, parent)
		@name = name
		@url = url
		@parent = parent
	end
	def get_url()
		@url
	end

	def get_parent()
		@parent
	end

	def get_name()
		@name
	end
	
	def to_hash
		{
			location_name: @name,
			location_url: @url,
			location_country: @parent
		}
	end

	def to_json
		to_hash.to_json
	end
	#def self.from_json string
	#	data = JSON.load string
	#	self.new data['name'], data['url'], data['parent']
	#end
end

class Partner
	def initialize(name, localaddress, siteUrl, faveurl, contact, country, location, lat, long)
		@name = name
		@local_address = localaddress
		@partner_url = siteUrl
		@fave_partner_url = faveurl
		@contact = contact
		@country = country
		@location = location
		@latitude = lat
		@longitude = long
		@acceptFavePay = false
	end

	def initialize(name, faveUrl, country)
		@name = name
		@fave_partner_url = faveUrl
		@country = country
		@acceptFavePay = false
	end 

	
	def set_address(address)
		@local_address = address
	end

	def set_partnerurl(siteUrl)
		@partner_url = siteUrl
	end
	
	def set_contact(contact)
		@contact = contact
	end

	def set_location(location)
		@location = location
	end

	def set_geolocation(lat,long)
		@latitude = lat
		@longitude = long
	end

	def set_acceptFavePay(acceptFavePay)
		@acceptFavePay = acceptFavePay
	end

	def get_location()
		@location
	end

	def get_country()
		@country
	end

	def get_all()
		#"@local_address", "@partner_url", "@fave_partner_url", "@contact", "@country", "@location", "@latitude", "@longitude"
		#[ "'{name}'", "'{local_address}'", "'{partner_url}'", "'{fave_partner_url}'", "'{contact}'", "'{country}'", "'{location}'", "'{latitude}'", "'{longitude}'"]

		[ @name, @local_address, @partner_url, @fave_partner_url, @contact, @country, @location, @latitude, @longitude, @acceptFavePay ]
	end

	def to_hash
		{
			partner_name: @name,
			local_address: @local_address,
			partner_url: @partner_url,
			fave_partnerUrl: @fave_partner_url,
			contact: @contact,
			country: @country,
			location: @location,
			latitude: @latitude,
			longitude: @longitude,
			acceptFavePay: @acceptFavePay
		}
	end

	def to_json
		to_hash.to_json
	end
end

class Partners
	def to_json
		$partner_list.each do | partner |
			partner.to_hash
		end.to_json
	end
end


def setup()
	#redis connection	
	@redis = Redis.new(host: "127.0.0.1", port: 6379)
	
	unparsed_page = HTTParty.get($url)
	parsed_page = Nokogiri::HTML(unparsed_page)
	mainlink_lists = parsed_page.css('div.ui.row.links.segment.transparent.new-footer-padding')
	mainlink_lists.each  do | link_lists |
		links = link_lists.css('div.col-xs-4.ui.new-footer-padding')
		links.each do | loc_links |
			locations = loc_links.css('a')
			parent = locations.first
			locations.each do | location |
				if location.text != parent.text
					loc = Location.new(location.text, location.attr('href'), parent.text)
					$partner_locations << loc
					@redis.sadd('locations_all', loc.to_json)
				elsif location.text.downcase == "singapore"
					#bug need to forcely added
					if location.attr('href') != "#"
						loc = Location.new(location.text, location.attr('href'), parent.text)
						$partner_locations << loc
						@redis.sadd('locations_all', loc.to_json)						
					end
				end
			end
		end 
	end
end

def scraper
	CSV.open('partners.csv', 'w') do | csv |
		#header
		#temporary - need to uncomment back
		csv << ["Partner Name", "Partner Address", "Partner Website", "Fave Partner Site", "Contact Information", "Country", "Location", "Latitude", "Longitude", "Accept FavePay"]
		$partner_locations.each do | loc |
			$atoz.each do | letter_num |
				local_directory_url = $url + loc.get_url + '/directory/partners?letter=' + letter_num
				puts '------- Scraping ' + local_directory_url + ' ---------'
				unparsed_page = HTTParty.get(local_directory_url)
				parsed_page = Nokogiri::HTML(unparsed_page)
				main_links = parsed_page.css('ul.ui.list')
				partner_links = main_links.css('li')

				partner_links.each do | partner_link |					

					partner_url = $url + partner_link.css('a').attr('href').value
					partner_unparsed = HTTParty.get(partner_url)
					partner_parsed = Nokogiri::HTML(partner_unparsed)

					puts 'Partner: ' + partner_parsed.css('a.section.active').text
					puts 'Partner Url: ' + partner_url
					puts 'Partner Parent Location: ' + loc.get_parent
					
					partner_obj = Partner.new(partner_parsed.css('a.section.active').text, partner_url, loc.get_parent)
					partner_obj.set_location(loc.get_name)
					
					#TODO: contact information #not-tested yet
					partner_outlets_block = partner_parsed.css('div.ui.small.modal.transition.visible.active.outlet-modal')
					if partner_outlets_block.empty?
					else					
						all_outlets = partner_outlets_block.css('div.ui.grid.no.padding.margin.popup-container')
						if all_outlets.empty?
							#need to handle this properly using other way. i'm pretty sure this is not correct.
						else						
							all_outlets.each do | outlet |
								outlet_info = outlet.css('div.outlet-address').text
								puts 'WOW! there are outlets'
							end
						end
					end

					#site_url
					partner_bottom = partner_parsed.css('div.ui.segment.bottom.attached')
					if partner_bottom.empty?
						#puts nothing
					else
						bottom = partner_bottom.css('a.external-link')
						if bottom.empty?
							#why it is here? ask me again next time
						else
							site_url = bottom.attr('href').value
							puts 'Partner Website :' + site_url
							partner_obj.set_partnerurl(site_url)
						end
					end 

					#get actual location with longitude, latitude (google maps)
					favepay_content = partner_parsed.css('div.favepay-div-content')
					if favepay_content.empty?
						#nothing here
					else
						favepay_spec = favepay_content.css('li')
						if favepay_spec.empty?
						else
							favepay_spec_1 = favepay_spec.first
							partner_spec = favepay_spec_1.css('a').attr('href').value
							partner_spec_url = $url + partner_spec
							partner_spec_unparsed = HTTParty.get(partner_spec_url)
							partner_spec_parsed = Nokogiri::HTML(partner_spec_unparsed)

							address_block = partner_spec_parsed.css('div.ui.segment.padding-bottom-0.borderless')
							if address_block.empty?
								#nothing here again? 
							else
								address = address_block.css('p').text
								puts 'Partner Address: ' + address
								script = address_block.css('script').text
								arr_str = script.split(':')
								latitude = arr_str[1].split(',')[0].strip
								longitude = arr_str[2].split(',')[0].strip

								puts 'Partner Address Latitude: ' + latitude
								puts 'Partner Address Longitude: ' + longitude
								#puts 'ApiKey: ' + arr_str[3].split('}')[0].strip
								
								partner_obj.set_address(address)
								partner_obj.set_geolocation(latitude, longitude)
								partner_obj.set_acceptFavePay(true)

								#TODO: want to do a lookup of phone number via latitude/longitude using GeoCoder
								#query = "#{latitude},#{longitude}"
								#first_result = Geocoder.search(query)

								#if first_result.empty?
								#	puts 'no result'
								#else
								#	puts 'got result'
								#end

							end
						end
					end
					

					csv << partner_obj.get_all
					$partner_list << partner_obj
					@redis.sadd('partners_all', partner_obj.to_json)
					@redis.sadd('partners_' + partner_obj.get_country.downcase, partner_obj.to_json)
					@redis.sadd('partners_' + partner_obj.get_country.downcase + '_' + partner_obj.get_location.downcase, partner_obj.to_json)

					#TODO: prepare offerings - not tested
					#offers = partner_parsed.css('div.ui.segments.borderless.no.margin')
					#off_text = offers.css('h5.ui.header').text
					#hasNoOffer = off_text.include? "No available offer"
					#puts 'Partner has no offer: ' + hasOffer
					#if hasNoOffer == true
					#	puts 'Partner has no offerings'
					#else
					#	puts off_text
					#end
					
				end

				puts '------- Scraping ' + local_directory_url + ' ---------'
				#byebug
			end
		end
	end 
end


setup
scraper