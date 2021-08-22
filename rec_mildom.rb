# coding: utf-8

require "time"
require "json"
require "open-uri"
require "dotenv"

def ffmpeg_path
  if RUBY_PLATFORM == "x64-mingw32"
    "ffmpeg.exe"
  else
    "ffmpeg"
  end
end

def sanitize_filename(file)
  file.gsub(%r![/\\?*:|"<>]!, "")
end

Dotenv.load

raise "usage: #{__FILE__} <user_id>" if ARGV.size != 1
user_id = ARGV[0]

loop do
  begin
    body = URI.open("#{ENV["API_URL"]}/api/v1/mildom/#{user_id}").read
    stat = JSON.parse(body)
    if !stat["online"]
      sleep(60)
      next
    end

    time_str = Time.now.strftime("%Y%m%d_%H%M%S")
    filename = sanitize_filename("#{stat["user_name"]}-#{time_str}-live-#{stat["stream_id"]}-#{stat["live_title"]}.mp4")

    system(
      ffmpeg_path,
      "-hide_banner",
      "-loglevel",
      "warning",
      "-headers",
      "Referer: https://www.mildom.com/",
      "-i",
      "https://do8w5ym3okkik.cloudfront.net/live/#{user_id}.m3u8",
      "-c",
      "copy",
      "-bsf:a",
      "aac_adtstoasc",
      filename,
    )
  rescue => e
    puts e.message
    sleep(60)
  end
end
