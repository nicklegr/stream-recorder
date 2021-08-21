# coding: utf-8

require "time"
require "json"
require "open-uri"
require "dotenv"
require_relative "https"
require_relative "twitter_space"

def ffmpeg_path
  if RUBY_PLATFORM == "x64-mingw32"
    "ffmpeg.exe"
  else
    "ffmpeg"
  end
end

Dotenv.load

raise "usage: #{__FILE__} <user_id>" if ARGV.size != 1
user_id = ARGV[0]

loop do
  body = URI.open("#{ENV["API_URL"]}/api/v1/twitter_space/user_id/#{user_id}").read
  stat = JSON.parse(body)
  if !stat["online"]
    sleep(60)
    next
  end

  space = TwitterSpace.new
  token = space.guest_token()
  stream = space.live_video_stream(token, stat["media_key"])
  url = stream["source"]["location"]
  screen_name = stat["screen_name"]
  space_id = stat["space_id"]
  live_title = stat["live_title"]

  time_str = Time.now.strftime("%Y%m%d_%H%M%S")
  system(
    ffmpeg_path,
    "-hide_banner",
    "-i",
    url,
    "-c",
    "copy",
    "#{screen_name}-#{time_str}-#{space_id}-#{live_title}.aac"
  )
end
