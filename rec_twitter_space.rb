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
    chat_access_token = stat["chat_access_token"]

    time_str = Time.now.strftime("%Y%m%d_%H%M%S")

    chat_file_basename = sanitize_filename("#{screen_name}-#{time_str}-#{space_id}-#{live_title}")

    recorder_pid = spawn(
      "node",
      "twitter_space_chat_record.js",
      chat_file_basename,
      space_id,
      chat_access_token
    )
    Process.detach(recorder_pid)

    audio_filename = sanitize_filename("#{screen_name}-#{time_str}-#{space_id}-#{live_title}.aac")
    puts "recording audio '#{audio_filename}'"
    system(
      ffmpeg_path,
      "-hide_banner",
      "-loglevel",
      "warning",
      "-i",
      url,
      "-c",
      "copy",
      audio_filename
    )
  rescue => e
    puts e.message
    sleep(60)
  end
end
