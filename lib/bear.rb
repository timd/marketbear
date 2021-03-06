# Copyright (c) 2009 Tim Duckett (www.adoptioncurve.net)
#
# Based on original code by James Smith (www.floppy.org.uk)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# http://www.opensource.org/licenses/mit-license.php

require 'open-uri'
require 'date'
require 'yaml'
require 'rubygems'

 gem 'hpricot', '>=0.6'
 require 'hpricot'
 require 'open-uri'
 require 'rubyful_soup'

# require 'twitter'
# require 'csv'

def main
  # Get config file from the config.yml file
  load_config
  
  # Get the status from the saved 'state' file
  load_state
  
  # For each configuration
  @@configs.each_pair do |name, config|
    # Get data
    print "fetching data\n"
    puts config['data-uri']
 
    rawdata = open(config['data_uri']) { |f| Hpricot(f) }

    open(@url,  "User-Agent" => "Ruby/#{RUBY_VERSION}",
                                "From" => "email@addr.com",
                                "Referer" => "http://www.igvita.com/blog/") { |f|

                   puts "Fetched document: #{f.data_uri}"#

                  # Save the response body
                  @response = f.read }

                  # Load the data into the doc variable
                  rawdata = Hpricot(@response)
    
    puts "Rawdata = " + rawdata.to_s
    # Parse datafile
    
    data = parse(rawdata)
    # Check if data feed has been updated
   
   puts "Data = " + data
   
      # Twitter
      # send_update_to_twitter(data, name, config)
    end
    # save_state
  
end

def load_config
  all_configs = YAML.load_file("#{File.dirname(__FILE__)}/../config/config.yml")
  @@configs = all_configs['datasets']
end

def load_state
  @@state = YAML.load_file("#{File.dirname(__FILE__)}/../data/state.yml") rescue nil
end

def save_state
  File.open("#{File.dirname(__FILE__)}/../data/state.yml", 'w') do |out|
   YAML.dump(@@state, out)
  end
end

def parse(rawdata)
  puts "Now parsing"
  data =  (rawdata/"/html/body").inner_html
  puts data
  return data
end

def send_update_to_twitter(data, config_name, config)  
  print "twittering... "
  if @@twitter_config.nil? or @@twitter_config[config_name].nil?
    print "not configured\n"
  else
    # Get config data
    y = config['year_col']
    m = config['month_col']
    # For each tweet in the current configuration
    @@twitter_config[config_name].each do |tweet|
      col = tweet['data_col']
      # Create tweet
      current = data.last
      previous = data[data.length - (tweet['compare_months_back'].to_i+1)]
      date = Date.new(current[y].to_i, current[m].to_i, 1)
      difference = current[col].to_f - previous[col].to_f
      direction = difference < 0 ? "down" : "up";
      percentage = (difference.abs / previous[col].to_f) * 100
      tweet = "#{tweet['prefix']} in #{date.strftime("%B %Y")} were #{current[col]}ppm, #{direction} #{sprintf("%.2f", difference)}ppm (#{sprintf("%.1f", percentage)}%) from #{tweet['suffix']}."
      # Post
      twitter ||= Twitter::Base.new(@@twitter_config['username'], @@twitter_config['password'])
      twitter.post(tweet)
    end
    print "OK\n"
  end
end

# Run
main