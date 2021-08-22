# coding: utf-8

require "time"
require "json"
require "open-uri"
require "dotenv"
require "optparse"
require "twitter"
require_relative "https"

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

def twitter_client
  client = Twitter::REST::Client.new do |config|
    config.consumer_key = ENV["CONSUMER_KEY"]
    config.consumer_secret = ENV["CONSUMER_SECRET"]
    config.access_token = ENV["OAUTH_TOKEN"]
    config.access_token_secret = ENV["OAUTH_TOKEN_SECRET"]
  end
  client
end

class Option
  def initialize
    opt = OptionParser.new

    opt.on("--list_ids=[list_ids]") {|v| @list_ids = v.split(",") }
    opt.on("--except_user_ids=[except_user_ids]") {|v| @except_user_ids = v.split(",") }

    opt.parse!(ARGV)
  end

  attr_reader :list_ids
  attr_reader :except_user_ids
end

Dotenv.load

option = Option.new

raise "usage: #{__FILE__} <list_ids>" if !option.list_ids

# TODO: ffmpegの存在をチェック

loop do
  begin
    # TODO: 定期的にAUTH_TOKENの有効性チェック

    user_ids = []
    client = twitter_client
    option.list_ids.each do |list_id|
      user_ids += client.list_members(list_id.to_i, { count: 5000 }).map{|e| e.id.to_s}
    end
    if option.except_user_ids
      user_ids -= option.except_user_ids
    end

# pp user_ids
# pp user_ids.size

    post_body = { "user_ids" => user_ids }.to_json
    body = Https.post("#{ENV["API_URL"]}/api/v1/twitter_space/bulk_check", {}, {}, post_body)
# puts body
    stats = JSON.parse(body)
    if stats.empty?
      sleep(60)
      next
    end

    puts "online_users: #{stats.map{|e| e["screen_name"]}.join(", ")}"
    rec_stat = stats.first

    url = rec_stat["stream_url"]
    screen_name = rec_stat["screen_name"]
    space_id = rec_stat["space_id"]
    live_title = rec_stat["live_title"]

    time_str = Time.now.strftime("%Y%m%d_%H%M%S")
    filename = sanitize_filename("#{screen_name}-#{time_str}-#{space_id}-#{live_title}.aac")

    puts "recording file '#{filename}'"

    system(
      ffmpeg_path,
      "-hide_banner",
      "-loglevel",
      "warning",
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
