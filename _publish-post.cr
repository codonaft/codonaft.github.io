#!/usr/bin/env crystal

require "colorize"
require "json"
require "uri"
require "yaml"

PROD_REPO_URI = "git@github.com:codonaft/codonaft.github.io.git"
PROD_BRANCH   = "master"

ALLOWED_TIME_DIFF = 5.minutes

class PostMetadata
  include YAML::Serializable

  @[YAML::Field(key: "date")]
  property raw_date : String

  @[YAML::Field(key: "title")]
  property title : String

  @[YAML::Field(key: "permalink")]
  property permalink : String

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

def sign(unsigned_event : String, bunker_uri, nostr)
  event = nak([
    "event",
    "--pow", nostr["min_read_pow"].to_s,
    "--connect", bunker_uri,
  ], unsigned_event)

  # nak(["verify"], event.to_json) # FIXME: fails due to incorrect string escaping?

  event
end

def approve(nostr, pubkey, event, backup_prefix, prod, relays)
  puts("approving own post")
  community = nostr["community"]
  now = Time.utc
  unsigned_approval_event = {
    "created_at" => now.to_unix,
    "kind"       => 4550,
    "tags"       => [
      ["a", "34550:#{pubkey}:#{community}"],
      ["e", event["id"]],
      ["p", event["pubkey"]],
      ["k", event["kind"].to_s],
    ],
    "content" => event.to_json,
  }.to_json

  print "bunker uri: "
  approval_bunker_uri = (gets || "").strip
  approval_event_json = sign(unsigned_approval_event, approval_bunker_uri, nostr).to_json

  approval_event_backup = "#{backup_prefix}.#{now.to_unix}.nostr.approval#{prod ? "" : ".test"}.json"
  File.write(approval_event_backup, approval_event_json)
  puts("saved event backup to #{approval_event_backup}")

  puts
  Colorize.with.yellow.surround(STDOUT) do
    approval_event_backup.to_pretty_json(STDOUT)
  end

  puts
  print("#{prod ? "PROD" : "TEST"} PUBLISH APPROVAL to #{relays}? [n] ")

  if (gets || "").strip == "y"
    loop do
      begin
        puts("publishing approval nostr event #{event["id"]}")
        puts(nak_raw(["event"] + relays, approval_event_json))
        puts("SUCCESS!")
        break
      rescue e
        puts(e)
        sleep(1.seconds)
      end
    end
  end
end

def main
  if ARGV.size < 2
    script = Path.new(__FILE__).relative_to(Dir.current)
    puts("usage:")
    puts("  BUNKER_URI='bunker://...' #{script} _posts/1984-11-11-actions-are-louder-than-words.md \"So keep building\nthings.\"")
    exit 1
  end

  repo_dir = File.dirname(File.realpath(__FILE__))
  Dir.cd(repo_dir)
  puts("current directory is #{repo_dir}")

  post = ARGV[0]
  message = ARGV[1]
  bunker_uri = ENV["BUNKER_URI"]

  raise "Post file has changed" if `git status --porcelain #{post}`.starts_with?(" M ")
  raise "git status failed" unless $?.success?

  config = YAML.parse(File.read("_config.yml"))
  post_base = File.basename(post).split(".")[0]
  post_date = Time.parse(post_base[0..10], "%Y-%m-%d", Time::Location::UTC)

  raise "Unexpected posts dir" unless File.basename(File.dirname(post)) == "_posts"
  posts_parent = File.dirname(File.dirname(File.realpath(post)))
  lang = posts_parent == repo_dir ? "en" : File.basename(posts_parent)

  supported_langs = config["defaults"]
    .as_a
    .map { |i| i["values"]["lang"]? }
    .reject { |i| i.nil? }
    .map { |i| i.not_nil!.as_s }
  raise "Unexpected language #{lang}" unless supported_langs.includes?(lang)

  nostr = config["theme_settings"]["nostr"]
  pubkey = nak(["decode", nostr["npub"].as_s])["pubkey"]
  community = nostr["community"]

  _, raw_metadata, body = File.read(post).split("---", limit: 3)
  metadata = PostMetadata.from_yaml(raw_metadata)
  raise "nostr metadata is already set" if metadata.nostr

  url = URI.parse(config["url"].as_s)
  url.path = metadata.permalink.rchop('/')
  content = "#{metadata.title}\n\n#{url.to_s}\n\n#{message}"

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

  event = sign(unsigned_event, bunker_uri, nostr)
  event_json = event.to_json

  prod = event["pubkey"] == pubkey
  Dir.mkdir_p(".backup")
  backup_prefix = ".backup/#{url.path.gsub('/', '_')}"
  event_backup = "#{backup_prefix}.#{now.to_unix}.nostr#{prod ? "" : ".test"}.json"
  File.write(event_backup, event_json)
  puts("saved event backup to #{event_backup}")

  relays = prod ? nostr["relays"].as_a.map(&.to_s) : ["ws://localhost:8080"]
  repo_uri = prod ? `git config --get remote.origin.url`.strip : Dir.current
  raise "git config failed" unless $?.success?
  branch = `git branch --show-current`.strip
  raise "git branch failed" unless $?.success?

  if prod
    raise "Unexpected prod repo uri" unless repo_uri == PROD_REPO_URI
    raise "Unexpected prod branch" unless branch == PROD_BRANCH
  end

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
  raise "git diff failed" unless $?.success?

  puts
  Colorize.with.yellow.surround(STDOUT) do
    event.to_pretty_json(STDOUT)
  end

  puts
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

        puts("publishing nostr event #{event["id"]}")
        puts(nak_raw(["event"] + relays, event_json))

        puts("SUCCESS!")
        break
      rescue e
        puts(e)
        sleep(1.seconds)
      end
    end

    approve(nostr, pubkey, event, backup_prefix, prod, relays)
  else
    system("git", ["checkout", post])
    puts("exiting")
  end
end

main
