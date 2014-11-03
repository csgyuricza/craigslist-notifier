#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'simple-rss'
require 'open-uri'
require 'gmail'
require 'logger'
require 'yaml'
require 'digest/md5'

BASE_PATH = File.expand_path(File.dirname(__FILE__))
SLEEP_DURATION = 60 # seconds

# Load the local config file
def config
  @config ||= YAML.load_file(BASE_PATH + '/local.config.yml')
end

log = Logger.new(STDOUT)
log.level = Logger::INFO

while true
  begin
    begin
      log.info('Started processing queries')
      config['queries'].each do |query|
        datafile = "#{BASE_PATH}/#{Digest::MD5.hexdigest(query['source'] + query['regex'])}.data"
        log.info("Searching for #{query['summary']}")
        begin
          SimpleRSS.parse(open(query['source']).read.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')).channel.items.each do |post|
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
        rescue StandardError => e
          log.error(e.message)
        end
      end
      log.info('Finished processing')
    end
    sleep SLEEP_DURATION
  rescue SignalException => e
    log.info('Exiting the program')
    exit
  end
end
