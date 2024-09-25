#!/usr/bin/env crystal

require "colorize"
require "json"
require "uri"
require "yaml"

ALLOWED_TIME_DIFF = 5.minutes

class PostMetadata
  include YAML::Serializable

  @[YAML::Field(key: "date")]
  property raw_date : String

  @[YAML::Field(key: "title")]
  property title : String

  @[YAML::Field(key: "categories")]
  property categories : String?

  @[YAML::Field(key: "nostr")]
  property nostr : YAML::Any?

  def date
    Time.parse!(@raw_date, "%Y-%m-%d %H:%M:%S %z")
  end

  def title
    @title.gsub(/<[^>]+>/, "")
  end

  def tags
    if @categories
      @categories.not_nil!.split(' ')
    else
      [] of String
    end
  end
end

def nak_raw(args, input = nil)
  output = Channel(Tuple(String, Process::Status)).new
  spawn do
    value = Process.run(command: "nak", args: args) do |p|
      if input
        p.input.puts(input)
        p.input.close
      end
      p.output.gets_to_end
    end
    output.send({value.strip, $?})
  end
  value, status = output.receive
  raise "#{args}: unexpected exit code #{status}, value=#{value}" unless status.success?
  value
end

def nak(args, input = nil)
  value = nak_raw(args, input)
  begin
    value = "{}" if value.empty?
    JSON.parse(value)
  rescue e
    puts(value)
    raise e
  end
end

def main
  if ARGV.size < 2
    script = Path.new(__FILE__).relative_to(Dir.current)
    puts("usage:")
    puts("  BUNKER_URI='bunker://...' #{script} _posts/1984-11-11-actions-are-louder-than-words.md \"Hello new line\nhello world\"")
    exit 1
  end

  repo_dir = File.dirname(File.dirname(File.realpath(__FILE__)))
  Dir.cd(repo_dir)

  post = ARGV[0]
  content = ARGV[1]
  bunker_uri = ENV["BUNKER_URI"]

  raise "Post file has changed" if `git status --porcelain #{post}`.starts_with?(" M ")

  config = YAML.parse(File.read("_config.yml"))
  post_base = File.basename(post).split(".")[0]
  post_date = Time.parse(post_base[0..10], "%Y-%m-%d", Time::Location::UTC)
  url = URI.parse(config["url"].as_s)
  url.path = post_base[11..-1]

  raise "Unexpected posts dir" if File.basename(File.dirname(post)) != "_posts"
  posts_parent = File.dirname(File.dirname(File.realpath(post)))
  lang = posts_parent == repo_dir ? "en" : File.basename(posts_parent)

  raise "Unexpected language #{lang}" if !["en", "ru"].includes?(lang) # TODO: read valid languages from config

  nostr = config["theme_settings"]["nostr"]
  pubkey = nak(["decode", nostr["npub"].as_s])["pubkey"]
  community = nostr["community"]

  _, raw_metadata, body = File.read(post).split("---", limit: 3)
  metadata = PostMetadata.from_yaml(raw_metadata)
  raise "nostr metadata is already set" if metadata.nostr

  now = Time.utc
  dt = now - metadata.date
  raise "Unexpected delta time #{dt}" if dt.negative? || dt > ALLOWED_TIME_DIFF
  raise "Inconsistent post filename/metadata date" unless post_date.year == metadata.date.year && post_date.month == metadata.date.month && post_date.day == metadata.date.day

  lang_label = "ISO-639-1"
  unsigned_event = {
    "content"    => content,
    "created_at" => metadata.date.to_unix,
    "kind"       => 1,
    "tags"       => [
      ["a", "34550:#{pubkey}:#{community}"],
      ["r", url.to_s],
      ["subject", metadata.title],
      ["L", lang_label],
      ["l", lang, lang_label],
    ] + metadata.tags.map { |t| ["t", t] },
  }.to_json

  event = nak([
    "event",
    "--pow", nostr["min_read_pow"].to_s,
    "--connect", bunker_uri,
  ], unsigned_event)

  event_json = event.to_json
  nak(["verify"], event_json)

  prod = event["pubkey"] == pubkey
  Dir.mkdir_p(".backup")
  event_backup = ".backup/#{url.path}.#{now.to_unix}.nostr#{prod ? "" : ".test"}.json"
  File.write(event_backup, event_json)
  puts("saved event backup to #{event_backup}")

  relays = prod ? nostr["relays"].as_a.map(&.to_s) : ["ws://localhost:8080"]
  repo_uri = prod ? `git config --get remote.origin.url`.strip : Dir.current

  note = nak_raw(["encode", "note", event["id"].as_s])
  new_raw_metadata = raw_metadata +
                     <<-STRING
                     nostr:
                       comments: #{note}
                     STRING

  File.write(post, ["---", new_raw_metadata, "\n---", body].join)

  Colorize.with.green.surround(STDOUT) do
    puts(`git diff #{post}`.strip)
  end

  puts
  Colorize.with.yellow.surround(STDOUT) do
    event.to_pretty_json(STDOUT)
  end

  puts
  branch = `git branch --show-current`.strip
  print("#{prod ? "PROD" : "TEST"} PUBLISH to #{repo_uri} (#{branch}) and #{relays}? [n] ")
  if (gets || "").strip == "y"
    puts("PUBLISHING...")

    puts("commiting changes to git")
    system("git add #{post} && git commit --no-gpg-sign --message 'Publish' #{post}")

    loop do
      begin
        puts("pushing changes to git")
        system("git push --force --repo #{repo_uri} origin #{branch}")
        status = $?
        raise "unexpected exit code #{status}" unless status.success?

        puts("publishing nostr event")
        puts(nak_raw(["event"] + relays, event_json))

        puts("SUCCESS!")
        break
      rescue e
        puts(e)
        sleep 1
      end
    end
  else
    system("git", ["checkout", post])
    puts("exiting")
  end
end

main
