#!/usr/bin/env ruby
require 'rubygems'
require 'simple-rss'
require 'open-uri'
require 'gmail'
require 'logger'
require 'yaml'
require 'digest/md5'

# Load the local config file
def config
  @config ||= YAML.load_file('local.config.yml')
end

BASE_PATH = File.expand_path(File.dirname(__FILE__))

log = Logger.new(STDOUT)
log.level = Logger::INFO

begin
  log.info('Started processing queries')
  config['queries'].each do |query|
    datafile = "#{BASE_PATH}/#{Digest::MD5.hexdigest(query['source'] + query['regex'])}.data"
    log.info("Searching #{query['summary']}")
    SimpleRSS.parse(open(query['source'])).channel.items.each do |post|
      title = post.title[/.*\)/] # skip unicode chars after the last parenthesis
      if title =~ Regexp.new(query['regex'], Regexp::IGNORECASE)
        known_urls = File.readlines(datafile).collect(&:strip) rescue known_urls = []
        if not known_urls.include?(post.link.strip) # If this is a new url...
          log.info('Found new post matching criteria - sending email...')
          File.open(datafile, 'a').puts(post.link.strip)
          gmail = Gmail.connect(config['gmail']['account'], config['gmail']['password'])
          gmail.deliver do
            to(query['email'])
            subject("#{query['summary']} => #{title}")
            body(post.link)
          end
          gmail.logout
        end
      end
    end
  end
  log.info('Finished processing')
rescue Exception => e
  log.error(e.message)
end