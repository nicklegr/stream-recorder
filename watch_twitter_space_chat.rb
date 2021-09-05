# coding: utf-8

require "time"
require "json"
require "open-uri"
require "dotenv"

Dotenv.load

raise "usage: #{__FILE__} <user_id>" if ARGV.size != 1
user_id = ARGV[0]

body = open("#{ENV["API_URL"]}/api/v1/twitter_space/user_id/#{user_id}").read
stat = JSON.parse(body)
if !stat["online"]
  puts "user is offline"
end

screen_name = stat["screen_name"]
space_id = stat["space_id"]
live_title = stat["live_title"]
chat_access_token = stat["chat_access_token"]

puts "watching #{screen_name}: #{live_title}"

system(
  "node",
  "twitter_space_chat_watch.js",
  space_id,
  chat_access_token
)
