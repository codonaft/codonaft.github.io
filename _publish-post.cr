#!/usr/bin/env crystal

require "colorize"
require "http/client"
require "json"
require "mime"
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

  @[YAML::Field(key: "feature-img")]
  property feature_img : String

  @[YAML::Field(key: "permalink")]
  property permalink : String

  @[YAML::Field(key: "tags")]
  property post_tags : Array(String)? # TODO: doesn't parse in all formats?

  @[YAML::Field(key: "nostr")]
  property nostr : YAML::Any?

  def time
    Time.parse!(@raw_date, "%Y-%m-%d %H:%M:%S %z")
  end

  def title
    @title.gsub(/<[^>]+>/, "")
  end

  def tags
    if @post_tags
      @post_tags.not_nil!
    else
      [] of String
    end
  end
end

def main
  if ARGV.size < 2
    script = Path.new(__FILE__).relative_to(Dir.current)
    puts("usage:")
    puts("  BUNKER_URI='bunker://...' AUTHORIZED_KEY='...' #{script} _posts/1984-11-11-actions-are-louder-than-words.md \"So keep building\nthings.\"")
    exit 1
  end

  repo_dir = File.dirname(File.realpath(__FILE__))
  Dir.cd(repo_dir)
  puts("current directory is #{repo_dir}")

  post = ARGV[0]
  message = ARGV[1]
  bunker_uri = ENV["BUNKER_URI"]
  authorized_key = ENV["AUTHORIZED_KEY"]

  raise "Post file has changed" if `git status --porcelain #{post}`.starts_with?(" M ")
  raise "git status failed" unless $?.success?

  config = YAML.parse(File.read("_config.yml"))
  post_base = File.basename(post).split('.')[0]
  post_date = Time.parse(post_base[0..10], "%Y-%m-%d", Time::Location::UTC).date

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

  url = URI
    .parse(config["url"].as_s)
    .resolve(metadata.permalink.rchop('/'))
    .normalize
  content = "#{metadata.title}\n\n#{url}\n\n#{message}"

  now = Time.utc
  dt = now - metadata.time
  raise "Unexpected delta time #{dt}" if dt.negative? || dt > ALLOWED_TIME_DIFF
  raise "Inconsistent post filename/metadata date" unless post_date == metadata.time.date

  feature_image_url = URI
    .parse(config["url"].as_s)
    .resolve(metadata.feature_img)
    .normalize
  feature_image_mime_type = MIME.from_filename(metadata.feature_img)

  lang_label = "ISO-639-1"
  unsigned_event = {
    "content"    => content,
    "created_at" => metadata.time.to_unix,
    "kind"       => 1,
    "tags"       => [
      ["a", "34550:#{pubkey}:#{community}"],
      ["r", url.to_s],
      ["subject", metadata.title],
      ["L", lang_label],
      ["l", lang, lang_label],
      ["imeta", "url #{feature_image_url}", "m #{feature_image_mime_type}"],
    ] + metadata.tags.map { |t| ["t", t.downcase] },
  }.to_json

  event = sign(unsigned_event, bunker_uri, authorized_key, nostr)
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

        await_successful_deployment(url)

        # TODO: make sure we never stuck here, retry transmission in case of network failure
        puts("publishing nostr event #{event["id"]}")
        puts(nak_raw(["event"] + relays, event_json))

        puts("SUCCESS!")
        break
      rescue e
        puts(e)
        wait(1.seconds)
      end
    end

    approve_and_broadcast(nostr, pubkey, event, backup_prefix, prod, relays, bunker_uri, authorized_key)

    puts("checking video availability")
    begin
      media_url = config["theme_settings"]["p2p_player"]["media_urls"].as_a[0].as_s
      video_url = `wget -qO - #{url.to_s} | grep --extended-regexp --only-matching '#{media_url}/.*m3u8'`
      video_ok = HTTP::Client.get(video_url).status.success?
      puts("#{video_url} is #{video_ok ? "ok" : "FAILED"}")
    rescue e
      puts(e)
    end
  else
    system("git", ["checkout", post])
    puts("exiting")
  end

  puts("FINISHED")
end

def nak_raw(args, input = nil)
  # TODO: exit after timeout
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

def sign(unsigned_event : String, bunker_uri : String, authorized_key : String, nostr)
  event = nak([
    "event",
    "--pow", nostr["min_read_pow"].to_s,
    "--connect", bunker_uri,
    "--connect-as", authorized_key,
  ], unsigned_event)

  # nak(["verify"], event.to_json) # FIXME: fails due to incorrect string escaping?

  event
end

def approve_and_broadcast(nostr, pubkey, event, backup_prefix, prod, relays, bunker_uri, authorized_key)
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

  approval_event = sign(unsigned_approval_event, bunker_uri, authorized_key, nostr)

  approval_event_backup = "#{backup_prefix}.#{now.to_unix}.nostr.approval#{prod ? "" : ".test"}.json"
  File.write(approval_event_backup, approval_event.to_json)
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
        puts("publishing approval nostr event #{approval_event["id"]} for #{event["id"]}")
        puts(nak_raw(["event"] + relays, approval_event.to_json))
        puts("SUCCESS!")
        break
      rescue e
        puts(e)
        wait(1.seconds)
      end
    end
  end

  # FIXME: hangs forever
  failed_relays = relays.reject do |relay|
    begin
      found_event(event, relay) && found_event(approval_event, relay)
    rescue e
      false
    end
  end
  puts("failed to publish to relays: #{failed_relays}") unless failed_relays.empty?

  if prod
    print("broadcast both events? [n] ")
    if (gets || "").strip == "y"
      broadcast(event, failed_relays)
      broadcast(approval_event, failed_relays)
    end
    puts("FINISHED")
  end
end

def broadcast(event : JSON::Any, failed_relays : Array(String))
  other_relays = begin
    File.read_lines("_relays.txt")
      .map { |i| i.strip }
      .to_set
  rescue e
    Set(String).new
  end

  begin
    relays_to_lookup = other_relays + failed_relays.to_set
    puts("looking for #{event["id"]} in #{relays_to_lookup.size}")
    relays = relays_to_lookup
      .reject { |i|
        begin
          i.empty? || found_event(event, i)
        rescue e
          false
        end
      }
      .to_a
    puts("broadcasting #{event["id"]} to #{relays.size}")
    puts(nak_raw(["event"] + relays, event.to_json))
  rescue e
    puts("failed to broadcast #{event.to_json}")
    puts(e)
  end
end

def found_event(event : JSON::Any, relay : String)
  nak(["req", "-i", event["id"].to_json, relay])["id"] == event["id"]
end

def await_successful_deployment(url : URI)
  wait(50.seconds)
  loop do
    status = HTTP::Client.get(url).status
    puts("#{url} responded with #{status}")
    break if status.success? || status.redirection?
    wait(10.seconds)
  end
end

def wait(time : Time::Span)
  puts("waiting #{time}")
  sleep(time)
end

main
