# coding: utf-8

require "time"
require "json"
require "open-uri"
require "dotenv"
require "optparse"
require "twitter"
require "fileutils"
require_relative "https"

SLEEP_SEC = 60

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

    @rec_dir_name = "space"

    opt.on("--list_ids=[list_ids]") {|v| @list_ids = v.split(",") }
    opt.on("--except_user_ids=[except_user_ids]") {|v| @except_user_ids = v.split(",") }
    opt.on("--rec_dir_name=[name]") {|v| @rec_dir_name = v }

    opt.parse!(ARGV)
  end

  attr_reader :list_ids
  attr_reader :except_user_ids
  attr_reader :rec_dir_name
end

Dotenv.load

option = Option.new

raise "usage: #{__FILE__} --list_ids=<list_ids> [--except_user_ids=<except_user_ids>] [--rec_dir_name=<name>]" if !option.list_ids

# TODO: ffmpegの存在をチェック

recording_pids = Hash.new {|hash, key| hash[key] = Hash.new}
pid_watchers = Hash.new {|hash, key| hash[key] = Hash.new}

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
      print(".")
      sleep(SLEEP_SEC)
      next
    end

    puts ""

    # pp recording_pids
    # pp pid_watchers

    puts "online_users: #{stats.map{|e| e["screen_name"]}.join(", ")}"

    stats.each do |stat|
      url = stat["stream_url"]
      screen_name = stat["screen_name"]
      space_id = stat["space_id"]
      live_title = stat["live_title"]
      chat_access_token = stat["chat_access_token"]

      dir = "#{option.rec_dir_name}/#{screen_name}"
      FileUtils.mkdir_p(dir)
      time_str = Time.now.strftime("%Y%m%d_%H%M%S")

      watcher = pid_watchers.dig(space_id, "chat")
      if !watcher || !watcher.status
        chat_file_basename = "#{dir}/" + sanitize_filename("#{screen_name}-#{time_str}-#{space_id}-#{live_title}")
        puts "recording chat '#{chat_file_basename}'"

        chat_recorder_pid = spawn(
          "node",
          "twitter_space_chat_record.js",
          chat_file_basename,
          space_id,
          chat_access_token
        )

        recording_pids[space_id]["chat"] = chat_recorder_pid
        pid_watchers[space_id]["chat"] = Process.detach(chat_recorder_pid)
      else
        puts "already recording chat: #{screen_name} (#{space_id})"
      end

      watcher = pid_watchers.dig(space_id, "audio")
      if !watcher || !watcher.status
        audio_filename = "#{dir}/" + sanitize_filename("#{screen_name}-#{time_str}-#{space_id}-#{live_title}.aac")
        puts "recording audio '#{audio_filename}'"

        audio_recorder_pid = spawn(
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

        recording_pids[space_id]["audio"] = audio_recorder_pid
        pid_watchers[space_id]["audio"] = Process.detach(audio_recorder_pid)
      else
        puts "already recording audio: #{screen_name} (#{space_id})"
      end
    end
  rescue Net::HTTPExceptions => e
    puts e.message
    puts e.response.body
    puts e.backtrace
  rescue => e
    puts e.message
    puts e.backtrace
  end

  sleep(SLEEP_SEC)
end
