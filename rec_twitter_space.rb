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

# TODO: ffmpegの存在をチェック

loop do
  begin
    # TODO: 定期的にAUTH_TOKENの有効性チェック

    body = URI.open("#{ENV["API_URL"]}/api/v1/twitter_space/user_id/#{user_id}").read
    stat = JSON.parse(body)
    if !stat["online"]
      sleep(60)
      next
    end

    url = stat["stream_url"]
    screen_name = stat["screen_name"]
    space_id = stat["space_id"]
    live_title = stat["live_title"]

    time_str = Time.now.strftime("%Y%m%d_%H%M%S")
    filename = sanitize_filename("#{screen_name}-#{time_str}-#{space_id}-#{live_title}.aac")

    system(
      ffmpeg_path,
      "-hide_banner",
      "-i",
      url,
      "-c",
      "copy",
      filename
    )
  rescue => e
    puts e.message
    sleep(60)
  end
end
