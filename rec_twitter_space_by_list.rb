# coding: utf-8

require "time"
require "json"
require "yaml"
require "open-uri"
require "dotenv"
require "optparse"
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

class Option
  def initialize
    opt = OptionParser.new

    @rec_dir_name = "space"

    opt.on("--users_yaml=[filename]") {|v| @users_yaml = v }
    opt.on("--except_user_ids=[except_user_ids]") {|v| @except_user_ids = v.split(",") }
    opt.on("--rec_dir_name=[name]") {|v| @rec_dir_name = v }

    opt.parse!(ARGV)
  end

  attr_reader :users_yaml
  attr_reader :except_user_ids
  attr_reader :rec_dir_name
end

Dotenv.load

option = Option.new

raise "usage: #{__FILE__} --users_yaml=<filename> [--except_user_ids=<except_user_ids>] [--rec_dir_name=<name>]" if !option.users_yaml

# TODO: ffmpegの存在をチェック

recording_pids = Hash.new {|hash, key| hash[key] = Hash.new}
pid_watchers = Hash.new {|hash, key| hash[key] = Hash.new}

loop do
  begin
    # TODO: 定期的にAUTH_TOKENの有効性チェック

    user_ids = []
    users_data = YAML.load_file(option.users_yaml)
    user_ids += users_data

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
      user_id = stat["user_id"]
      space_id = stat["space_id"]
      live_title = stat["live_title"]
      chat_access_token = stat["chat_access_token"]

      dir = "#{option.rec_dir_name}/#{screen_name}-#{user_id}"
      FileUtils.mkdir_p(dir)
      time_str = Time.now.strftime("%Y%m%d_%H%M%S")

      watcher = pid_watchers.dig(space_id, "chat")
      if !watcher || !watcher.status
        chat_file_basename = "#{dir}/" + sanitize_filename("#{time_str}-#{space_id}-#{live_title}")
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
        audio_filename = "#{dir}/" + sanitize_filename("#{time_str}-#{space_id}-#{live_title}.aac")
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
