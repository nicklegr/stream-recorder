# coding: utf-8

require "time"
require "json"
require "open-uri"
require "dotenv"
require "fileutils"

def ffmpeg_path
  if RUBY_PLATFORM == "x64-mingw32"
    "ffmpeg.exe"
  else
    "ffmpeg"
  end
end

def sanitize_filename(file)
  file.gsub(%r![/\\?*:|"<>\n]!, "")
end

Dotenv.load

raise "usage: #{__FILE__} <user_id>" if ARGV.size != 1
user_id = ARGV[0]

loop do
  begin
    body = URI.open("#{ENV["API_URL"]}/api/v1/spoon/#{user_id}").read
    stat = JSON.parse(body)
    if !stat["online"]
      sleep(60)
      next
    end

    dir = "spoon/@#{stat["screen_name"]}-#{user_id}"
    FileUtils.mkdir_p(dir)
    time_str = Time.now.strftime("%Y%m%d_%H%M%S")
    filename = "#{dir}/" + sanitize_filename("#{time_str}-#{stat["nickname"]}-live-#{stat["stream_id"]}-#{stat["live_title"]}.ts")

    puts "recording stream '#{filename}'"
    system(
      ffmpeg_path,
      "-hide_banner",
      "-loglevel",
      "warning",
      "-headers",
      "Referer: https://www.spooncast.net/",
      "-i",
      "https://jp-hana-live.spooncast.net/cast/#{stat["stream_id"]}/playlist.m3u8",
      "-c",
      "copy",
      filename,
    )
    puts "stream ended"
  rescue Net::HTTPExceptions => e
    puts e.message
    puts e.response.body
    puts e.backtrace
  rescue => e
    puts e.message
    puts e.backtrace
  end

  sleep(60)
end
