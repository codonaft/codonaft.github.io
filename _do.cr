#!/usr/bin/env crystal

# runs CI/development cycle
# _hosts and _ohmyvps are two-directionally synchronizable

require "colorize"
require "digest/sha256"
require "file_utils"
require "http/client"
require "ini"
require "json"
require "uri"
require "yaml"

DEBUG = ARGV.empty? || !["sync", "sync-nostr", "build", "deploy", "health"].includes?(ARGV[0])
TRACE = ENV["TRACE"]? == "1"

WILDCARD_HOST = "0.0.0.0"

DEBUG_HOST = "localhost"
# DEBUG_HOST = WILDCARD_HOST

MEDIA_HOST  = "media.codonaft"
MIRROR_HOST = "mirror.codonaft"

PUBLIC_MEDIA_HOST = "#{MEDIA_HOST}.com"

# ssh media.codonaft -- "sudo apk add --no-cache rust && rustc --print target-cpus | grep native | sed 's/.* (currently //;s/)\.//' && sudo apk del --no-cache rust"
TARGET_CPU = {
  MEDIA_HOST  => "nocona",
  MIRROR_HOST => "broadwell",
}

ALPINE_VERSION           = "3.21.3"
AQUATIC_VERSION          = "0.9.0"
BROWSER_DETECTOR_VERSION = "4.1.0"
HLS_VERSION              = "1.5.15"
MEDIA_CAPTIONS_VERSION   = "1.0.4"
MEDIA_ICONS_VERSION      = "1.1.5"
P2P_MEDIA_LOADER_VERSION = "2.0.1"
RUST_VERSION             = "1.86.0"
TINYLD_VERSION           = "1.3.4"

CODEC_AV1  = "av01.0.09M.08.0.110.01.01.01.0"
CODEC_H264 = "avc1.64002a"
CODEC_OPUS = "opus"
CODEC_AAC  = "mp4a.40.2"

# OPUS_BITRATE_KBPS = 510
OPUS_BITRATE_KBPS = 256

BANDWIDTH_MB_PER_SEC = 20
IGNORE_HOSTS         = ["personal.tracker.com", "tracker.novage.com.ua", "www.googletagmanager.com"]

MAIN_SITE_CONFIG = Path["_config.yml"]

HOSTS_DIR        = Path["_hosts"]
BUILD_DIR        = Path[".build"]
CACHE_DIR        = BUILD_DIR.join(".cache")
BANLISTS         = CACHE_DIR.join("banlists.txt")
BROKEN_POST_URLS = CACHE_DIR.join("broken_post_urls.txt")
COMMON_ROOT      = Path["_ohmyvps/alpine/alpine-root"]

SERVER_MEDIA_DIR = Path["var/www"].join(PUBLIC_MEDIA_HOST)
MEDIA_BUILD_DIR  = BUILD_DIR.join(MEDIA_HOST, SERVER_MEDIA_DIR)

MIRROR_FROM_TO = [
  {MEDIA_HOST, [{MIRROR_HOST, SERVER_MEDIA_DIR}]},
]

USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"

def main
  repo_dir = Path[File.dirname(File.realpath(__FILE__))]
  Dir.cd(repo_dir)

  ps = processes()
  check(ps)

  config = YAML.parse(File.read(MAIN_SITE_CONFIG))
  if !ARGV.empty? && (ARGV.includes?("-h") || ARGV.includes?("--help"))
    usage
  elsif ARGV.size == 1 && ARGV[0] == "sync"
    check_ssh_hosts(ps)
    sync
  elsif ARGV.size >= 1 && ARGV[0] == "sync-nostr"
    profiles = ARGV.size > 1 && ARGV[1] == "profiles"
    sync_nostr(config, profiles: profiles, output_relays: ["ws://localhost:7777", "wss://nostr.codonaft.com", "wss://purplepag.es", "wss://nostr.oxtr.dev", "wss://nostr.girino.org"])
  elsif ARGV.size == 1 && ARGV[0] == "health"
    check_ssh_hosts(ps)
    health(config)
  elsif ARGV.size >= 1 && ARGV[0] == "build"
    update
    build
    if ARGV.size == 2 && ARGV[1] == "run"
      serve(DEBUG_HOST)
    end
  elsif ARGV.size > 2 && ARGV[0] == "encode"
    encode_media(ARGV[1], config, ARGV[2])
  elsif ARGV.size == 1 && ARGV[0] == "deploy"
    check_ssh_hosts(ps)
    deploy(config)
  elsif ARGV.size == 1 && ARGV[0] == "cloudflare-banlist"
    expr_begin = "ip.src in {"
    expr_end = "}"
    max_len = 4096 - expr_begin.size - expr_end.size
    ips = Dir
      .glob(".build/*/var/tmp/local-banlist.txt")
      .flat_map { |i| File.read_lines(i) }
      .map { |i| i.strip }
      .select { |i| i.size > 0 }
      .sort
      .uniq
      .join(' ')
    while ips.size > 0
      end_index = ips.rindex(' ', max_len)
      if end_index.nil? || ips.size <= max_len
        puts("#{expr_begin}#{ips.strip}#{expr_end}\n\n")
        break
      else
        puts("#{expr_begin}#{ips[0..end_index].strip}#{expr_end}\n\n")
        ips = ips[end_index..].strip
      end
    end
  elsif ARGV.empty? || ARGV[0] == "debug"
    update
    build
    serve(DEBUG_HOST)
  else
    usage
  end
end

def usage
  script = Path["./"].join(Path.new(__FILE__).relative_to(Dir.current))
  puts(
    <<-STRING
       usage:

       #{script} [debug]
         build, serve jekyll in debug mode locally

       #{script} build
         update and build in release mode
           without deloying

       #{script} build run
         same, also serve jekyll in release mode locally

       #{script} deploy
         update, build, sync and deploy to PROD
           without pushing to the git repos
         run health checks

       #{script} sync
         sync to PROD
           download newest non-conflicting versioned files to _ohmyvps and _hosts
           upload newest files from _ohmyvps, _hosts and .build

       #{script} sync-nostr [profile]
         fetch nostr events, push them to my relays
         don't send events to profile-specific relays by default

       #{script} health
         run health checks

       #{script} cloudflare-banlist
         generate ban-lists for Security - WAF

       #{script} encode path/to/video-name.mkv <en|ru>
       #{script} encode https://youtu.be/CB9bS46vl04 <en|ru>
         encode (or download and transcode) media to HLS, put it to #{MEDIA_BUILD_DIR}/video-name/
         supported media is 1080p60 + yuv420p + bt709

       use TRACE=1 env variable for more messages
       STRING
  )
  exit 1
end

def deploy(config)
  update
  build
  sync
  configure(config)
  start
  health(config)
end

def build
  step("build")

  if DEBUG
    warn("DEBUG\n")
  else
    ok("PROD\n")
  end

  Dir.mkdir_p(CACHE_DIR, 0o755)

  build_vidstack_player
  build_zapthreads

  build_jekyll(MIRROR_HOST, configs: [MAIN_SITE_CONFIG, Path["_config.i2p.yml"]]) unless DEBUG
  build_jekyll(MIRROR_HOST, configs: [MAIN_SITE_CONFIG, Path["_config.tor.yml"]]) unless DEBUG

  build_rust_app(
    MEDIA_HOST,
    crate: "aquatic_ws",
    version: AQUATIC_VERSION,
    dependencies: ["clang17-libclang", "cmake", "findutils", "g++", "linux-headers", "liburing", "make", "rust-bindgen"],
    cflags: "-D_GNU_SOURCE",
    rustflags: "\\$(rustc --print target-features | grep '    avx512' | grep -v 'avx512fp16' | awk '{print \\$1}' | sed 's/^/-C target-feature=-/' | xargs)",
  )

  build_rust_app(
    MEDIA_HOST,
    crate: "broadcastr",
    git: URI.parse("https://github.com/codonaft/broadcastr"),
    dependencies: ["g++", "openssl-dev", "openssl-libs-static"],
  )

  build_rust_app(
    MEDIA_HOST,
    crate: "rnostr",
    branch: "codonaft",
    git: URI.parse("https://github.com/codonaft/rnostr"),
    dependencies: ["g++", "openssl-dev", "openssl-libs-static"],
  )
end

def configure(config)
  if DEBUG
    warn("skipping configure\n")
    return
  end
  step("configure")
  configure_rnostr(MEDIA_HOST, config)
end

def start
  if DEBUG
    warn("skipping start\n")
    return
  end
  step("start")
  start_openrc(MIRROR_HOST, services: ["i2pd", "local", "nginx", "tor"])
  start_openrc(MEDIA_HOST, services: ["aquatic_ws", "broadcastr", "rnostr", "i2pd", "local", "nginx", "tor"])
end

def encode_media(input : String, config : YAML::Any, language : String)
  step("encode")
  Dir.mkdir_p(CACHE_DIR, 0o755)
  header = ["#EXTM3U", "#EXT-X-VERSION:7", "#EXT-X-INDEPENDENT-SEGMENTS"]
  audio, video =
    if input.starts_with?("https://")
      url = URI.parse(input)
      raise "unexpected url" unless url.hostname == "youtu.be"
      output_dir = MEDIA_BUILD_DIR.join(url.path)

      download_youtube_thumbnail(url, output_dir)
      [
        transcode_youtube(url, config, output_dir, "audio", [{[251], CODEC_OPUS}, {[234], CODEC_AAC}]),
        transcode_youtube(url, config, output_dir, "video", [{[399], CODEC_AV1}, {[299, 312], CODEC_H264}]),
      ]
    else
      raw_media = Path[input]
      raise "non-empty file #{raw_media} not found" unless nonempty_exists?(raw_media)
      duration = get_duration(raw_media).not_nil!
      name = raw_media.basename.split('.')[..1][0]
      output_dir = MEDIA_BUILD_DIR.join(name)
      Dir.mkdir_p(output_dir, 0o755)
      [encode_audio(raw_media, duration, output_dir), encode_video(raw_media, duration, config, output_dir)]
    end

  audio_items = audio.map_with_index { |item, index|
    codec, playlist, tracks = item.not_nil!
    default = index == 0 ? "YES" : "NO"
    [
      "#EXT-X-MEDIA:TYPE=AUDIO",
      "GROUP-ID=\"#{codec}\"",
      "NAME=\"#{language}\"",
      "LANGUAGE=\"#{language}\"",
      "AUTOSELECT=#{default}",
      "DEFAULT=#{default}",
      "CHANNELS=\"2\"",
      "URI=\"#{playlist}\"",
    ].join(',')
  }.reverse # iOS stucks when opus is the first playlist item

  video_items = video.cartesian_product(audio).map do |video, audio|
    video_codec, video_playlist, video_tracks, video_duration = video.not_nil!
    audio_codec, _, audio_tracks, audio_duration = audio.not_nil!
    duration = [video_duration, audio_duration]
      .reject { |i| i.nil? }
      .map { |i| i.not_nil! }
      .min
    bandwidth = bitrate(video_tracks, duration) + bitrate(audio_tracks, duration)
    codecs = [video_codec, audio_codec].join(',')
    item = [
      "#EXT-X-STREAM-INF:BANDWIDTH=#{bandwidth}",
      "CODECS=\"#{codecs}\"",
      "RESOLUTION=#{resolution(video_tracks)}",
      "FRAME-RATE=60",
      "AUDIO=\"#{audio_codec}\"",
    ].join(',')
    [item, video_playlist]
  end
    .reverse # iOS stucks when opus is the first playlist item
    .flatten

  File.write(output_dir.join("main.m3u8"), (header + audio_items + video_items).join('\n'))
  output = "sha256sum.txt"
  system("find #{output_dir} -type f -print0 | xargs -0 sha256sum | grep -v #{output} > #{output_dir.join(output)}")
end

def update
  step("update")
  system(<<-STRING
    set -eu
    #{TRACE ? "set -x" : ""}
    #{update_fonts}
    #{update_media_icons}
    #{update_media_captions}
    #{update_hls}
    #{update_p2p_media_loader}
    #{update_tinyld}
    wait
    STRING
  )
end

def sync
  if DEBUG
    warn("skipping sync\n")
    return
  end
  step("sync")

  puts("running sanity checks")
  [COMMON_ROOT, HOSTS_DIR].each do |dir|
    raise "uncommited changes in #{dir}" if `git -C #{dir} status --porcelain .`.starts_with?(" M ")
  end

  unless Dir.exists?("_ohmyvps")
    system("git clone git@github.com:codonaft/ohmyvps.git _ohmyvps")
  end
  unless Dir.exists?("_vidstack-player")
    system("git clone git@github.com:codonaft/vidstack-player.git _vidstack-player")
  end
  unless Dir.exists?("_zapthreads")
    system("git clone git@github.com:codonaft/zapthreads-codonaft.git _zapthreads")
  end

  hosts = all_hosts()
  puts("hosts: #{hosts}")

  mirror = MIRROR_FROM_TO.map { |source_host, destination_and_files|
    {source_host, destination_and_files.select { |destination_host, _| hosts.includes?(destination_host) }}
  }.to_h

  common_files = git_ls(COMMON_ROOT)
  hosts_files : Hash(String, Set(Path)) = hosts.map { |host|
    host_dir = HOSTS_DIR.join(host)
    files = git_ls(host_dir)
    {host, files}
  }.to_h

  hosts.map { |host|
    done = Channel(Nil | Exception).new
    spawn do
      begin
        sync_host(host, hosts_files: hosts_files, common_files: common_files, mirror_to: mirror[host]?)

        backup_dir = Path[".backup"].join(host)
        continue_download(host, backup_dir, [Path["var/log/nginx/access.log"]])

        done.send(nil)
      rescue e
        error("host=#{host} sync failure: #{e}\n")
        done.send(e)
      end
    end
    done
  }.each { |i|
    e = i.receive
    raise e unless e.nil?
  }

  ok("sync finished\n")
end

def sync_host(host : String, *, hosts_files : Hash(String, Set(Path)), common_files : Set(Path), mirror_to : Array({String, Path}) | Nil)
  host_files : Set(Path) = hosts_files[host]
  all_hosts_files : Set(Path) = hosts_files
    .flat_map { |_, files| files.to_a }
    .to_set

  # puts "all_hosts_files = #{all_hosts_files}\n\n\ncommon_files = #{common_files}\n\n\n"

  host_dir = HOSTS_DIR.join(host)
  filtered_sync(host, COMMON_ROOT, download: common_files - all_hosts_files, upload: common_files - host_files)
  filtered_sync(host, host_dir, two_way: host_files)

  host_build_dir = BUILD_DIR.join(host)
  host_build_files = children_recursive(host_build_dir).to_set
  filtered_sync(host, host_build_dir, upload: host_build_files) # TODO: with --delete specifically for jekyll ?

  unless mirror_to.nil?
    mirror_to.each { |destination_host, dir|
      mirror_host_files = host_files.select { |i| i.to_s.starts_with?(dir.to_s) }
      mirror_host_build_files = host_build_files.select { |i| i.to_s.starts_with?(dir.to_s) }
      filtered_sync(destination_host, HOSTS_DIR.join(host), upload: mirror_host_files.to_set)
      filtered_sync(destination_host, BUILD_DIR.join(host), upload: mirror_host_build_files.to_set)
    }
  end

  ssh(host, ["sudo etckeeper commit sync 2>>/dev/null"])
end

def continue_download(host : String, local_dir : Path, files : Enumerable(Path))
  Dir.mkdir_p(local_dir)
  checks = files
    .map { |i| [i, local_dir.join(i)] }
    .select { |(i, local_full)| File.file?(local_full) }
    .map { |(i, local_full)|
      command = "head -c #{File.size(local_full)} /#{i} | sha256sum | cut -d' ' -f 1"
      expected_checksum = `sha256sum #{local_full} | cut -d' ' -f 1`.strip
      [command, expected_checksum]
    }
  checksums = ssh(host, checks.map { |(command, _)| command }).split('\n').reject { |i| i.empty? }
  raise "unexpected output" unless checks.size == checksums.size
  failures = checksums.zip(checks.map { |(_, expected_checksum)| expected_checksum }).reject { |a, b| a == b }
  raise "some checksums failed: #{failures}" unless failures.empty?
  rsync(local_dir, files, ["--append-verify", "#{host}:/", "."])
end

def add_user_commands(user : String)
  home_dir = Path["/var/lib"].join(user)
  [
    "sudo useradd --system --create-home --home-dir #{home_dir} --user-group --shell /sbin/nologin #{user} 2>>/dev/null",
    "sudo chmod 00700 #{home_dir}",
  ]
end

def start_openrc(host : String, *, services : Array(String))
  ssh(
    host,
    services.flat_map { |i| [
      "sudo rc-update add #{i} default",
      "sudo rc-service --ifstopped #{i} start",
      "sudo rc-service --ifcrashed #{i} restart",
    ] },
    tty: true
  )
end

def ssh(host : String, commands : Array(String), *, tty : Bool = false)
  return "" if commands.empty?
  if tty
    input = (commands + ["exit"]).join(';').gsub("'", '"')
    system("ssh -tt #{host} /bin/sh <<< '#{input}'")
    "" # FIXME
  else
    input = commands.join(';').gsub("'", '"')
    `ssh #{host} -- '#{input}'`.strip
  end
end

def serve(host : String, *, destination = Path["/_site"])
  step("serve")
  output_dir = BUILD_DIR.join(host, destination)
  system("bundle exec jekyll serve --future --host #{host} --destination #{output_dir}")
end

def health(config)
  if DEBUG
    warn("skipping health\n")
    return
  end
  step("health")

  all_hosts().each { |host|
    step(host)
    ssh(host, ["sudo /etc/init.d/nginx checkconfig", "sudo hdparm -t /dev/sd[a-z] | sed \"s!.*= !!\""], tty: true)
  }

  warn("github commit hash is different\n") unless JSON.parse(HTTP::Client.get("https://api.github.com/repos/codonaft/codonaft.github.io/commits").body)[0]["sha"].as_s == `git rev-parse HEAD`.strip

  banlists =
    if nonempty_exists?(BANLISTS) && File.info(BANLISTS).modification_time + 1.days > Time.utc
      File.read_lines(BANLISTS).to_set
    else
      update_banlists
    end

  site_url = URI.parse(config["url"].as_s)
  p2p_player_config = config["theme_settings"]["p2p_player"]
  site_hosts = find_hosts(site_url.hostname)

  stuns = p2p_player_config["ice_servers"]
    .as_a
    .map { |i| i.as_s.gsub("stun:", "").gsub(/:.*/, "").strip }
    .reject { |i| i.empty? }

  cdns = `git grep --only-matching --extended-regexp "(<script.*src=|import[(]*)['\\"]*https://[a-zA-Z0-9._-]*"`
    .split('\n')
    .map { |i| i.gsub(/.*https:\/\//, "").strip }
    .reject { |i| i.empty? }

  broken_post_urls =
    if nonempty_exists?(BROKEN_POST_URLS) && File.info(BROKEN_POST_URLS).modification_time + 30.days > Time.utc
      File.read_lines(BROKEN_POST_URLS).to_set
    else
      update_broken_post_urls
    end
  if broken_post_urls.empty?
    ok("all post URLs are ok\n")
  else
    warn("#{broken_post_urls.size} broken post URLs: #{broken_post_urls}\n")
  end

  check_domain(site_url)

  bancheck = "_bancheck.txt"
  custom_hosts =
    if File::Info.readable?(bancheck)
      File
        .read_lines(bancheck)
        .map { |i| i.strip }
        .reject { |i| i.empty? }
    else
      [] of String
    end

  https_hosts = (site_hosts + cdns + custom_hosts)
    .reject { |i| IGNORE_HOSTS.includes?(i) }
    .to_set
  general_hosts = stuns.to_set + https_hosts

  ignored_nostr_relays = JSON.parse(
    File.read(HOSTS_DIR.join(MEDIA_HOST).join(Path["/etc/broadcastr/blocked.json"])))
    .as_a
    .map { |i| URI.parse(i.as_s) }
    .to_set
  trackers = p2p_player_config["trackers"].as_a.map { |i| URI.parse(i.as_s) }

  # TODO
  relay_mirrors = [
    "ws://codonaftct3jsouvfyrjq4yumyngzv3el2msndf5oddccktgghnw7eyd.onion/nostr",
    "ws://codonaftct3jsouvfyrjq4yumyngzv3el2msndf5oddccktgghnw7eyd.onion/nostr/publish",
  ].map { |i| URI.parse(i) }

  other_relays = File
    .read_lines("_relays.txt")
    .map { |i| i.strip }
    .reject { |i| i.empty? }
    .map { |i| URI.parse(i) }
    .reject { |i| i.hostname.nil? || i.hostname == "localhost" } + relay_mirrors
  wss_uris = (trackers + other_relays + `git grep --only-matching 'wss://[a-zA-Z0-9/._-]*'`
    .split('\n')
    .map { |i| i.strip.gsub(/.*wss:\/\//, "") }
    .reject { |i| i.empty? || IGNORE_HOSTS.any? { |ignored| i.includes?(ignored) } }
    .map { |i| URI.parse("wss://#{i}") })
    .reject { |i| i.hostname.nil? || (ignored_nostr_relays.includes?(i) && !other_relays.includes?(i)) }
    .to_set

  with_socks_proxy("ru", ->(proxy : URI) {
    Dir.children(HOSTS_DIR).each { |i|
      print("#{i} ")
      check_icmp(i)
      puts
    }
    general_hosts.each { |i|
      print("#{i} ")
      check_icmp(i)
      check_ban(i, banlists)
      puts
    }
    wss_uris.each { |i|
      print("#{i} ")
      check_ban(i.hostname.not_nil!, banlists)
      check_ws(i, proxy)
      puts
    }
    https_hosts.each { |i|
      https_uri = URI.parse("https://#{i}")
      check_certificate(https_uri, proxy)
      check_ech(https_uri)
      puts
    }
  })
end

def with_socks_proxy(country, f : URI ->)
  used_tcp_ports = Set.new(`ss --tcp --listening | grep --only-matching --extended-regexp ':[0-9]{1,}'`
    .strip
    .split('\n')
    .map { |i| UInt16.new(i.gsub(':', "")) })

  name = "tor-#{country}"
  port = 9050
  exposed_port_from_container = `podman port #{name} | grep --only-matching --extended-regexp ':[0-9]{1,}$'`.strip.gsub(':', "")
  is_stopped = exposed_port_from_container.empty?

  exposed_port =
    if is_stopped
      (1024_u16..UInt16::MAX).find { |i| !used_tcp_ports.includes?(i) }.not_nil!
    else
      UInt16.new(exposed_port_from_container)
    end
  proxy = URI.parse("socks5://127.0.0.1:#{exposed_port}")

  # needs_restart = is_stopped || `podman logs #{name}`.includes?("All routers are down")
  if is_stopped
    system(<<-STRING
      podman run --replace --detach --name '#{name}' -p '#{proxy.host}:#{proxy.port}:#{port}' -it "alpine:#{ALPINE_VERSION}" /bin/sh -c "
      set -xeuo pipefail

      apk add --update --no-cache tor

      tor --SocksPort '#{WILDCARD_HOST}:#{port}' \
        --ExitNodes '{#{country}}' \
        --ExitRelay 0 \
        --StrictNodes 1 \
        --NumEntryGuards 1 \
        --NumDirectoryGuards 1 \
        --MaxCircuitDirtiness 10 \
        --HiddenServiceStatistics 0 \
        --Log #{TRACE ? "debug" : "notice"}"
      STRING
    )
  end

  puts("initializing tor")
  loop do
    break if `podman logs #{name}`.includes?("Bootstrapped 100%")
    sleep(1.seconds)
  end

  f.call(proxy)
end

def configure_rnostr(host, config)
  ssh(host, add_user_commands("rnostr"))
end

def check_icmp(host)
  output = `ping -c1 #{host} 2>&1 | grep --extended-regexp '(^ping:|100%|time=[0-9\\.]*)' | sed 's!.*time=!!;s!.*transmitted, !!'`.strip
  if output.starts_with?("ping:") || output.includes?("100%")
    error(output)
  else
    ok(output)
  end
end

def check_ech(host : URI)
  body = JSON.parse(HTTP::Client.get("https://dns.google/resolve?name=#{host.hostname}&type=HTTPS").body)
  answer = body["Answer"]?
  return if answer.nil? || answer.as_a?.nil?
  has_ech = answer.as_a.any? { |i|
    data = i["data"]?
    return false if data.nil? || data.as_s?.nil?
    data.as_s.includes?("ech=")
  }
  error(" ECH is enabled") if has_ech
end

def check_ws(host : URI, proxy : URI)
  now = Time.utc
  output = `echo -n | websocat --socks5 '#{proxy.host}:#{proxy.port}' -v #{host} 2>&1`
  if output.includes?("Both directions finished")
    latency = (Time.utc - now).milliseconds
    ok("#{latency} ms")
  else
    failure = output.split('\n').select { |i| i.includes?("WebSocketError") }
    error("#{host} is unavailable: #{failure}")
  end
end

def check_certificate(host : URI, proxy : URI)
  print("certificate for #{host.hostname} expires on ")
  begin
    raw = `curl --proxy #{proxy} --verbose --insecure #{host} 2>&1 | grep '\\*  expire date'`
      .strip
      .split(": ")[1]
    time = Time.parse!(raw, "%b %e %T %Y %Z")
    print_expiration(time)
  rescue e
    error(e)
  end
end

def check_domain(url : URI)
  domain = url.hostname
  print("domain #{domain} expires on ")
  time = `whois #{domain}`
    .split("\n")
    .select { |i| i.includes?("Expiry Date:") || i.includes?("Expiration Date:") }
    .map { |i|
      start = i.index(": ")
      if start.nil?
        nil
      else
        i[start + 1..].strip
      end
    }
    .select { |i| !i.nil? && !i.empty? && i[-1] == 'Z' }
    .map { |i| Time.parse_rfc3339(i.not_nil!) }
    .min
  print_expiration(time)
  puts
end

def check_ban(host : String, banlists : Set(String))
  pattern = [host] + `nslookup #{host}`
    .split('\n')
    .skip(3)
    .select { |i| i.starts_with?("Address: ") }
    .map { |i| i.split(' ') }
    .select { |i| i.size > 1 }
    .map { |i| i[1].strip }
  is_banned = pattern.any? { |i| banlists.includes?(i) && i == host || i == "www.#{host}" }
  error("#{host} is probably banned") if is_banned
end

def update_banlists
  puts("updating banlists")

  sbc = `wget -qO - https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts || wget -qO - http://sbc.io/hosts/hosts`
    .split('\n')
    .select { |i| i.starts_with?("#{WILDCARD_HOST} ") }
    .reject { |i| i == "#{WILDCARD_HOST} #{WILDCARD_HOST}" }
    .map { |i| i.split(' ') }
    .select { |i| i.size > 1 }
    .map { |i| i[1] }

  zi_zip = CACHE_DIR.join("zi.zip")
  zi = `
    wget -qO #{zi_zip} https://github.com/zapret-info/z-i/archive/refs/heads/master.zip && \
    unzip -p #{zi_zip} 'z-i-master/nxdomain.txt' 'z-i-master/dump*.csv' | \
      cat | \
      iconv -fcp1251 | \
      cut -d ';' -f2`
    .split('\n')
    .reject { |i| i.starts_with?("Updated: ") }
    .flat_map { |i| i.split('|') }
  File.delete(zi_zip)

  rb_prefix = "https://reestr.rublacklist.net/api/v3"
  rb_dpi = JSON.parse(HTTP::Client.get("#{rb_prefix}/dpi/").body).as_a.flat_map { |i| i["domains"].as_a }
  rb_domains_and_ips = ["ct-domains", "domains", "ips"]
    .flat_map { |request|
      JSON
        .parse(HTTP::Client.get("#{rb_prefix}/#{request}/").body)
        .as_a
    }
  rb = (rb_dpi + rb_domains_and_ips).map { |i| i.as_s }

  result = (sbc + zi + rb)
    .map { |i| i.strip }
    .reject { |i| i.empty? }
    .to_set
  raise "banlists fetch failure" if result.empty?
  File.write(BANLISTS, result.join('\n'))
  result
end

def update_broken_post_urls
  all_urls = `git grep '(https://' **/*.md | grep --only-matching 'https://[a-zA-Z0-9%?=#()/._-]*'`
    .split('\n')
    .map { |i| i.rchop(')').strip }
    .reject { |i| i.empty? }
    .map { |i|
      begin
        URI.parse(i)
      rescue e
        nil
      end
    }
    .reject { |i| i.nil? }
    .to_set

  puts("checking #{all_urls.size} post URLs")

  broken_urls = all_urls
    .map { |i|
      done = Channel(Tuple(URI, Bool)).new
      spawn do
        url = i.not_nil!
        result = begin
          HTTP::Client.get(url).status_code == 404
        rescue e
          false
        end
        done.send({url, result})
      end
      done
    }
    .map { |i| i.receive }
    .select { |_, i| i }
    .map { |url, _| url.not_nil!.to_s }

  File.write(BROKEN_POST_URLS, broken_urls.join('\n'))
  broken_urls
end

def check(ps : Array(Tuple(Int64, String)))
  current_ps_name = "/#{Path[__FILE__].basename}"
  raise "other instance keeps running" if ps
                                            .select { |(_, i)| i.includes?("crystal") && i.includes?(current_ps_name) }
                                            .any? { |(pid, _)| pid != Process.ppid }

  system("which bsdtar bundle css-minify git nak node pnpm podman rsync scour svgcleaner svgo uglifyjs wget >>/dev/null")
  raise "missing deps, run: cd && npm install 'css-minify@2.0.0' 'svgo@3.3.2' && USE='lz4 xxhash zstd' emerge '=app-arch/libarchive-3.7.9' '=app-arch/unzip-6.0_p27-r1' '=app-containers/podman-5.3.2' '=dev-ruby/bundler-2.4.22' '=dev-lang/crystal-1.16.1' '=dev-util/uglifyjs-3.16.1' '=dev-vcs/git-2.49.0-r2' '=media-gfx/scour-0.38.2-r1' '=media-sound/opus-tools-0.2-r1' '=media-libs/libwebp-1.4.0' '=media-video/mediainfo-24.11' '=net-dns/bind-tools-9.18.0-r1' '=net-libs/nodejs-22.13.1' '=net-misc/rsync-3.4.1' '=net-misc/wget-1.25.0' '=sys-apps/pnpm-bin-9.6.0' && cargo install --locked 'svgcleaner@0.9.5' 'websocat@1.13.0' && go install github.com/fiatjaf/nak@latest" unless $?.success?
  system("podman ps >>/dev/null")
  raise "podman failed" unless $?.success?

  files_with_unexpected_newlines = `grep --recursive vim:nofixendofline _includes`
    .strip
    .split('\n')
    .map { |i| i.split(':')[0] }
    .select { |i| File.read(i).includes?('\n') }
  raise "unexpected newline in #{files_with_unexpected_newlines}" unless files_with_unexpected_newlines.empty?
end

def build_rust_app(
  host : String,
  *,
  crate : String,
  version : String | Nil = nil,
  git : URI | Nil = nil,
  branch : String | Nil = nil,
  executables : Array(String) = [] of String,
  cflags : String = "",
  rustflags : String = "",
  dependencies : Array(String) = [] of String,
)
  if executables.empty?
    executables = [crate]
  end

  bin_dir = BUILD_DIR.join(host, "/usr/local/bin")
  if executables.all? { |i| nonempty_exists?(bin_dir.join(i)) }
    warn("skipping #{crate}\n")
    return
  end
  trace("building #{crate}\n")
  Dir.mkdir_p(bin_dir, 0o755)

  alpine_version = ssh(host, ["cat /etc/alpine-release"])
  alpine_version = ALPINE_VERSION if alpine_version.empty?
  warn("alpine #{host} version #{alpine_version} != alpine build version #{ALPINE_VERSION}") unless alpine_version == ALPINE_VERSION
  target_cpu = TARGET_CPU[host]

  cargo_args =
    if git.nil?
      raise "unspecified version" if version.nil?
      "#{crate} --version #{version}"
    else
      raise "either version or branch is allowed" if !version.nil? && !branch.nil?
      version = version.nil? ? "" : " --tag #{version}"
      branch = branch.nil? ? "" : " --branch #{branch}"
      "--git #{git}#{version}#{branch}"
    end

  install_executables_commands = executables
    .map { |i| "mv ~/.cargo/bin/#{i} /build" }
    .join("\n")

  system(<<-STRING
    podman run --rm -it -v "#{bin_dir}:/build" "alpine:#{alpine_version}" /bin/sh -c "
    set -xeuo pipefail

    apk add --update --no-cache 'cargo>=#{RUST_VERSION}' 'rust>=#{RUST_VERSION}' || {
      apk add --update --no-cache rustup
      rustup-init -y --profile minimal --default-toolchain '#{RUST_VERSION}'
    }

    export CFLAGS='-march=#{target_cpu} -O3 -mno-rdrnd #{cflags}'
    export CXXFLAGS='-march=#{target_cpu} -O3 -mno-rdrnd #{cflags}'
    export RUSTFLAGS=\\"-C target-cpu=#{target_cpu} -C force-frame-pointers=y #{rustflags}\\"
    export PATH=\\"\\${HOME}/.cargo/bin:\\${PATH}\\"

    apk add --update --no-cache git #{dependencies.join(" ")}
    cargo install --force --locked #{cargo_args}
    #{install_executables_commands}"
  STRING
  )
end

def build_vidstack_player
  system(<<-STRING
    set -xeuo pipefail
    cd _vidstack-player
    pnpm install
    pnpm build:vidstack
    killall turbo || :
    rsync -a -v --delete packages/vidstack/dist-npm/cdn/with-layouts/ ../assets/js/vendor/vidstack-player/
    mkdir -p ../assets/css/vendor/vidstack-player
    cp -v packages/vidstack/dist-npm/player/styles/default/{theme.css,layouts/video.css} ../assets/css/vendor/vidstack-player/
  STRING
  )
  raise "vidstack build failure" unless $?.success?
end

def build_zapthreads
  system(<<-STRING
    set -xeuo pipefail
    cd _zapthreads
    [ -d node_modules ] || npm install
    node_modules/.bin/vite build #{DEBUG ? "--minify false --mode debug" : ""}
    mv dist/zapthreads.iife.js ../assets/js/vendor/
  STRING
  )
  raise "zapthreads build failure" unless $?.success?
end

def build_jekyll(host : String, *, configs : Array(Path))
  prepare_jekyll

  upstream_url = configs.map { |i| YAML.parse(File.read(i))["theme_settings"]["upstream_url"]? }.select { |i| !i.nil? }[0]?
  url = URI.parse(configs.reverse.map { |i| YAML.parse(File.read(i))["url"] }.select { |i| !i.nil? }[0].as_s)
  destination = Path["/var/www"].join(url.hostname.not_nil!)
  output_dir = BUILD_DIR.join(host, destination)

  # if File.directory?(output_dir) && File.directory?("vendor")
  #   warn("skipping jekyll #{destination}\n")
  #   return
  # end
  Dir.mkdir_p(output_dir, 0o755)
  configs_arg = configs.empty? ? "" : "--config #{configs.join(',')}"
  system("bundle exec jekyll build --future --destination #{output_dir} #{configs_arg}")
  raise "jekyll build failure" unless $?.success?
  unless upstream_url.nil?
    system("sed --in-place 's!#{upstream_url.as_s.gsub('.', "\\.")}!#{url}!g' #{output_dir.join("sitemap.xml")}")
    raise "failed to update sitemap" unless $?.success?
  end
end

def prepare_jekyll
  unless File.directory?("vendor")
    FileUtils.rm_rf(["Gemfile.lock", ".bundle"])
    system(<<-STRING
      set -xeuo pipefail
      gem update bundler
      gem install bundler jekyll
      bundle config set --local path 'vendor/bundle'
      bundle install
    STRING
    )
    raise "initial prepare_jekyll failure" unless $?.success?
  end

  compress_options = "pure_getters"
  compress_options = "#{compress_options},drop_console" unless DEBUG

  system(<<-STRING
    set -euo pipefail
    #{TRACE ? "set -x" : ""}

    css-minify --dir assets/css/vendor/ --output assets/css/vendor/ &

    find assets/js/partials -type f -name '*.js' -print0 | \
      sort --zero-terminated | \
      xargs -0 cat | \
      uglifyjs \
        --validate \
        --mangle \
        --compress "#{compress_options}" \
        --output assets/js/main.min.js &

    for i in $(find assets/js/vendor -name '*.js' -not -name '*.min.js' | grep -vE '/(vidstack-player|media-icons|media-captions|zapthreads|hls|p2p-media-loader)') ; do
      uglifyjs \
        "$i" \
        --validate \
        --mangle \
        --compress "#{compress_options}" \
        --output "${i%*.js}.min.js" &
    done

    wait
  STRING
  )
  raise "prepare_jekyll failure" unless $?.success?
end

def update_tinyld
  <<-STRING
    wget -q 'https://cdn.jsdelivr.net/npm/tinyld@#{TINYLD_VERSION}/dist/tinyld.light.browser.js' -O 'assets/js/vendor/tinyld.min.js' &
  STRING
end

def update_browser_detector
  <<-STRING
    for i in browser-dtector.js{,.map} ; do
      wget -q "https://cdn.jsdelivr.net/npm/browser-dtector@#{BROWSER_DETECTOR_VERSION}/dist/$i" -O "assets/js/vendor/$i" &
    done
  STRING
end

def update_hls
  <<-STRING
    for i in hls.min.js{,.map} ; do
      dest="$i"
      #if [[ "$i" == *.min.js ]]; then
      #  dest="${i%.min.js}.js"
      #fi
      wget -q "https://cdn.jsdelivr.net/npm/hls.js@#{HLS_VERSION}/dist/$i" -O "assets/js/vendor/${dest}" &
    done
  STRING
end

def update_p2p_media_loader
  # https://www.jsdelivr.com/package/npm/p2p-media-loader-core?tab=files&path=dist
  # https://www.jsdelivr.com/package/npm/p2p-media-loader-hlsjs?tab=files&path=dist
  <<-STRING
    for pack in core hlsjs ; do
      for i in "p2p-media-loader-${pack}.es.min.js"{,.map} ; do
        dest="$i"
        wget -q "https://cdn.jsdelivr.net/npm/p2p-media-loader-${pack}@#{P2P_MEDIA_LOADER_VERSION}/dist/$i" -O "assets/js/vendor/${dest}" &
      done
    done
  STRING
end

def update_media_icons
  <<-STRING
     for i in {lazy.min,icons/{accessibility,add-note,add-playlist,add-user,add,airplay,arrow-collapse-in,arrow-collapse,arrow-down,arrow-expand-out,arrow-expand,arrow-left,arrow-right,arrow-up,bookmark,camera,chapters,chat-collapse,chat,check,chevron-down,chevron-left,chevron-right,chevron-up,chromecast,clip,closed-captions-on,closed-captions,comment,computer,device,download,episodes,eye,fast-backward,fast-forward,flag,fullscreen-arrow-exit,fullscreen-arrow,fullscreen-exit,fullscreen,heart,info,language,link,lock-closed,lock-open,menu-horizontal,menu-vertical,microphone,mobile,moon,music-off,music,mute,next,no-eye,notification,odometer,pause,picture-in-picture-exit,picture-in-picture,play,playback-speed-circle,playlist,previous,question-mark,queue-list,radio-button-selected,radio-button,repeat-on,repeat-square-on,repeat-square,repeat,replay,rotate,search,seek-backward-10,seek-backward-15,seek-backward-30,seek-backward,seek-forward-10,seek-forward-15,seek-forward-30,seek-forward,send,settings-menu,settings-switch,settings,share-arrow,share,shuffle-on,shuffle,stop,subtitles,sun,theatre-mode-exit,theatre-mode,thumbs-down,thumbs-up,timer,transcript,tv,user,volume-high,volume-low,x-mark}}.js ; do
       wget -q "https://cdn.jsdelivr.net/npm/media-icons@#{MEDIA_ICONS_VERSION}/dist/$i" -O "assets/js/vendor/media-icons/$i" &
     done
  STRING
end

def update_media_captions
  <<-STRING
     for i in {prod,prod/{errors,index,srt-parser,ssa-parser}.min}.js ; do
       dest="$i"
       if [[ "$i" == *.min.js ]]; then
         dest="${i%.min.js}.js"
       fi
       wget -q "https://cdn.jsdelivr.net/npm/media-captions@#{MEDIA_CAPTIONS_VERSION}/dist/$i" -O "assets/js/vendor/media-captions/${dest}" &
     done
  STRING
end

def update_fonts
  <<-STRING
    # https://github.com/majodev/google-webfonts-helper https://gwfh.mranftl.com/fonts
    api='https://gwfh.mranftl.com/api/fonts/'

    # FIXME: https://github.com/majodev/google-webfonts-helper/issues/184
    noto_color_emoji_url=$(
      wget -qO - --user-agent='#{USER_AGENT}' 'https://fonts.googleapis.com/css?family=Noto Color Emoji:400' | \
        grep 'Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.2.woff2' | \
        sed 's!.*url(!!;s!) format.*!!') && \
          wget "${noto_color_emoji_url}" -qO 'assets/fonts/noto-color-emoji-v34-emoji-regular.woff2' &

    font_uris=(
      #'noto-color-emoji?download=zip&subsets=emoji&variants=regular' # FIXME: https://github.com/majodev/google-webfonts-helper/issues/184
      'open-sans?download=zip&subsets=cyrillic,latin&variants=700,regular'
      'roboto?download=zip&subsets=cyrillic,latin&variants=100,300'
      'roboto-condensed?download=zip&subsets=cyrillic,latin&variants=regular'
    )

    for i in "${font_uris[@]}" ; do
      wget -qO - "${api}${i}&formats=woff2" | bsdtar -xvf- -C 'assets/fonts' &
    done
  STRING
end

def filtered_sync(host : String, local_dir : Path, *,
                  two_way : Set(Path) = Set(Path).new,
                  download : Set(Path) = Set(Path).new,
                  upload : Set(Path) = Set(Path).new)
  download_files = (two_way + download).select { |i| synchronizable(i) }
  upload_files = (two_way + upload).select { |i| synchronizable(i) }
  return if (download_files.empty? && upload_files.empty?) || !Dir.exists?(local_dir)

  trace(<<-STRING
          filtered_sync host=#{host} local_dir=#{local_dir}
            download:
              #{download_files.join("\n    ")}
            upload:
              #{upload_files.join("\n    ")}\n\n
          STRING
  )

  rsync(local_dir, download_files, ["#{host}:/", "./"])
  rsync(local_dir, upload_files, ["./", "#{host}:/"])
end

def synchronizable(path : Path)
  dir = path.parts[0]
  dir != "home" && path != Path["etc/conf.d/nginx"]
end

def rsync(source_dir : Path, files : Enumerable(Path), args : Enumerable(String))
  hashsum = Digest::SHA256.new.update((files + args).join.to_slice).hexfinal
  files_from = CACHE_DIR.join("sync-#{source_dir.to_s.gsub('/', '_')}.#{hashsum}.txt")
  File.write(files_from, files.join('\n'))
  system(
    <<-STRING
       set -euo pipefail
       #{TRACE ? "set -x" : ""}
       cd #{source_dir}
       rsync \
         --rsync-path='sudo /usr/bin/rsync' \
         --bwlimit=#{BANDWIDTH_MB_PER_SEC}m \
         --archive \
         --no-perms \
         --no-group \
         --no-owner \
         --chmod=go-w \
         --itemize-changes \
         --update \
         --checksum \
         --compress \
         --sparse \
         --files-from=#{File.expand_path(files_from)} #{Process.quote(args)}
       STRING
  )
  status = $?
  File.delete(files_from)

  some_attrs_not_transferred = 5888
  raise "unexpected rsync exit status=#{status.system_exit_status} source_dir=#{source_dir} args=#{args}" unless status.success? || status.system_exit_status == some_attrs_not_transferred
end

def check_i2p_host(host : String)
  puts("checking i2p configuration at #{host}")
  service_dir = Path["/var/lib/i2pd"]
  private_keys = File.read_lines(HOSTS_DIR.join(host).join("etc/i2pd/tunnels.conf"))
    .select { |i| i.starts_with?("keys =") }
    .map { |i| i.split(" = ")[1] }
  check_manual_upload(host, owner: "i2pd", group: "i2pd", mode: 700, path: service_dir)
  private_keys.each { |i| check_manual_upload(host, owner: "i2pd", group: "i2pd", mode: 440, path: service_dir.join(i)) }
end

def check_tor_host(host : String)
  puts("checking tor configuration at #{host}")
  service_dirs = File.read_lines(HOSTS_DIR.join(host).join("etc/tor/torrc"))
    .select { |i| i.starts_with?("HiddenServiceDir") }
    .map { |i| Path[i.split(" ")[1]] }
  service_dirs.map { |i|
    check_manual_upload(host, owner: "tor", group: "tor", mode: 700, path: i)
    check_manual_upload(host, owner: "tor", group: "tor", mode: 400, path: i.join("hs_ed25519_secret_key"))
    check_manual_upload(host, owner: "tor", group: "tor", mode: 400, path: i.join("hs_ed25519_public_key"))
    check_manual_upload(host, owner: "tor", group: "tor", mode: 400, path: i.join("hostname"), data: i.basename)
  }
end

def check_ssh_hosts(ps : Array(Tuple(Int64, String)))
  step("check_ssh_hosts")
  all_hosts()
    .map { |i|
      check_existing_ssh_connection(i, ps)
      done = Channel(Nil | Exception).new
      spawn do
        begin
          raise "unexpected timezone" unless ssh(i, ["date +%Z"]) == "UTC"

          remote_now = Time.unix(ssh(i, ["date --utc +%s"]).to_i)
          now = Time.utc
          raise "#{i}: time is out of sync" if (remote_now - now).abs > 2.seconds

          last_reboot = ssh(i, ["grep 'received a new kernel' /var/log/messages | tail -n1"])
          unless last_reboot.empty?
            reboot_time = Time.parse_utc("#{Time.utc.year} #{last_reboot}", "%Y %b %e %T")
            raise "#{i}: possibly rebooting right now" if (reboot_time - now).abs < 10.seconds
          end

          check_i2p_host(i)
          check_tor_host(i)

          while ssh(i, ["sudo pgrep --count --parent $(sudo pgrep --exact crond | paste -sd ',')"]).to_i > 0
            puts("#{i}: running a cron job")
            sleep(1.seconds)
          end

          done.send(nil)
        rescue e
          done.send(e)
        end
      end
      done
    }
    .each { |i|
      e = i.receive
      raise e unless e.nil?
    }
end

def check_existing_ssh_connection(host : String, ps : Array(Tuple(Int64, String)))
  raise "multiplexed ssh://#{host} not found" unless ps.any? { |_, i|
                                                       i.starts_with?("ssh: ") && i.ends_with?("[mux]") && i.includes?("@#{host}:")
                                                     }
end

def check_manual_upload(host : String, *, owner : String, group : String, mode : UInt16, path : Path, data : String? = nil)
  commands = ["stat -c %U,%G,%a"]
  commands += ["cat"] unless data.nil?
  output = ssh(host, commands.map { |i| "sudo #{i} #{path}" }).strip.split('\n')
  stat = output[0].split(',')

  raise "#{path}: unexpected owner" unless stat[0] == owner
  raise "#{path}: unexpected group" unless stat[1] == group
  raise "#{path}: unexpected mode" unless stat[2].to_i == mode
  raise "#{path}: unexpected data" unless data.nil? || output[1] == data
end

def sync_nostr(config, *, profiles : Bool, output_relays : Array(String))
  # TODO: do the same thing as cron bash job that uses rust nostr cli client? connect to relays over tor?

  limit = 100
  now = Time.utc
  from = now - 3.years # TODO: last commit date? last blog date? previous blog date?
  to = now + 15.minutes
  profile_kinds = [0, 3, 10002]

  nostr_config = config["theme_settings"]["nostr"]
  npub = nostr_config["npub"].as_s
  pk = JSON.parse(`nak decode #{npub}`)["pubkey"].as_s

  profile_relays = nostr_config["profile_relays"].as_a.map { |i| i.as_s }
  relays = nostr_config["relays"].as_a.map { |i| i.as_s }
  read_cache_relays = nostr_config["read_cache_relays"].as_a.map { |i| i.as_s }
  input_relays : Array(String) = relays + read_cache_relays + profile_relays

  step("sync-nostr")
  trace("pk=#{pk} input_relays=#{input_relays} output_relays=#{output_relays}")

  nak = "nak req --limit #{limit} --since #{from.to_unix} --until #{to.to_unix}"

  mentions = parse_nostr_events(`#{nak} -p #{pk} #{input_relays.join(' ')}`)
    .reject { |i|
      return false unless i["tags"].as_a.any? { |t| t.size > 1 && t[0] == "p" && t[1] == pk }
      k = i["kind"].as_i
      [3, 1984, 4454].includes?(k) || (k >= 5000 && k <= 7000) || (k >= 10000 && k <= 10102) || (k >= 20000 && k < 30000) || (k >= 30000 && k <= 30267)
    }
  puts("fetched #{mentions.size} mentions")

  parsed_authored_events = parse_nostr_events(`#{nak} -a #{pk} #{input_relays.join(' ')}`)
  authored_events = parsed_authored_events
    .reject { |i|
      return false unless i["pubkey"].as_s == pk
      k = i["kind"].as_i
      [4454, 10044].includes?(k) || (k >= 20000 && k < 30000)
    }
  puts("fetched #{authored_events.size} authored events")

  puts("writing events")
  nak_raw(["event"] + output_relays, (mentions + authored_events).map { |i| i.to_json })

  if profiles
    # TODO: check spam
    fetch_comments_command = ([nak, "-k", "1", "-p", pk] + input_relays).join(' ')
    trace(fetch_comments_command)
    comments_pks = parse_nostr_events(`#{fetch_comments_command}`)
      .select { |i| i["kind"].as_i == 1 && i["pubkey"].as_s != pk }
      .map { |i| i["pubkey"].as_s }.to_set
    request_profiles_command = (
      [nak, "--since", "0", "-k", "0"] + comments_pks.map { |i| "-a #{i}" } + input_relays
    ).join(' ')
    trace(request_profiles_command)
    comments_profile_events = parse_nostr_events(`#{request_profiles_command}`)
      .select { |i| i["kind"].as_i == 0 }
      .group_by { |i| i["pubkey"].as_s }
      .reject { |p, _| p == pk }
      .map { |_, g| g.max_by { |i| i["created_at"].as_i } }
    puts("profile events of commenters = #{comments_profile_events.size}")

    request_author_profile_events_command = (
      [nak, "--since", "0", "-a", pk] + profile_kinds.map { |k| "-k #{k}" } + input_relays
    ).join(' ')
    trace(request_author_profile_events_command)
    author_profile_events = parse_nostr_events(`#{request_author_profile_events_command}`)
      .select { |i| profile_kinds.includes?(i["kind"].as_i) }
    puts("author profile events = #{author_profile_events.size}")
    nak_raw(["event"] + profile_relays, (comments_profile_events + author_profile_events).map { |i| i.to_json })
  end
  puts("finished writing events")
end

def nak_raw(args, input : Array(String) = [] of String)
  # TODO: exit after timeout
  output = Channel(Tuple(String, Process::Status)).new
  trace("running nak #{args}")
  spawn do
    value = Process.run(command: "nak", args: args) do |p|
      input.each do |line|
        trace("writing stdin")
        p.input.puts(line)
        trace("writing stdin ok")
      end
      trace("closing stdin")
      p.input.close
      trace("closed stdin")
      trace("reading stdout")
      result = p.output.gets_to_end
      trace("finished reading stdout")
      result
    end
    trace("sending stdout")
    output.send({value.strip, $?})
    trace("sent stdout")
  end
  trace("waiting for stdout")
  value, status = output.receive
  trace("received stdout")
  raise "#{args}: unexpected exit code #{status}, value=#{value}" unless status.success?
  value
end

def parse_nostr_events(text)
  text
    .split('\n')
    .reject { |i| i.strip.empty? }
    .to_set
    .map { |i| JSON.parse(i) }
end

def processes
  Dir.entries("/proc")
    .select { |entry| entry =~ /^\d+$/ }
    .flat_map { |pid|
      begin
        cmdline = File.read("/proc/#{pid}/cmdline").gsub('\0', ' ').strip
        [{pid.to_i64, cmdline}]
      rescue ex : IO::Error
        [] of Tuple(Int64, String)
      end
    }
end

def children_recursive(dir : Path) : Array(Path)
  children_recursive_inner(dir).map { |i| i.relative_to(dir) }
end

def children_recursive_inner(dir : Path) : Array(Path)
  Dir.children(dir)
    .flat_map { |i|
      full : Path = dir.join(i)
      if File.file?(full)
        [full]
      elsif File.directory?(full)
        children_recursive_inner(full)
      else
        [] of Array(Path)
      end
    }
    .map { |i| Path[i] }
end

def all_hosts : Array(String)
  # TODO: from args
  Dir.children(HOSTS_DIR)
end

def find_hosts(host : String?) : Array(String)
  return [] of String unless host

  result = `git grep --only-matching --extended-regexp '[a-zA-Z0-9._-]*#{host.gsub(".", "\\.")}'`
    .split('\n')
    .map { |i| i.split(':') }
    .select { |i| i.size > 2 }
    .map { |i| i[2].strip }
    .reject { |i| i.empty? }
    .to_set
  (result + [host].to_set).to_a
end

def maybe_transcode_hls(input : Path, duration : Float, codec, stream_type, output_dir : Path)
  stream_output_dir = output_dir.join(codec)
  Dir.mkdir_p(stream_output_dir, 0o755)

  playlist_m3u8 = "#{stream_type}.m3u8"
  temp_playlist_m3u8 = "temp.m3u8"
  template = stream_output_dir.join("%08d.ts")
  playlist = stream_output_dir.join(playlist_m3u8)

  ffmpeg_encode(
    input,
    playlist,
    <<-STRING
      -c copy \
      -pix_fmt yuv420p \
      -f hls \
      -g 48 \
      -keyint_min 48 \
      -sc_threshold 0 \
      -hls_time 4 \
      -hls_list_size 0 \
      -hls_playlist_type vod \
      -hls_segment_type fmp4 \
      -master_pl_name #{temp_playlist_m3u8} \
      -hls_segment_filename #{template}
      STRING
  )

  codecs_pattern = "CODECS=\""
  temp_playlist = stream_output_dir.join(temp_playlist_m3u8)
  parsed_codec = File
    .read_lines(temp_playlist)
    .select { |i| i.includes?(codecs_pattern) }
    .map { |i| i.split(codecs_pattern)[1]? }
    .reject { |i| i.nil? }
    .map { |i| i.not_nil!.split('"')[0]? }
    .reject { |i| i.nil? }[0]?
  raise "unexpected codec #{parsed_codec} (expected #{codec})" unless parsed_codec.nil? || parsed_codec == codec
  File.delete(temp_playlist)

  tracks = JSON.parse(`mediainfo --Output=JSON #{input}`)["media"]["track"].as_a

  {codec, "#{codec}/#{playlist_m3u8}", tracks, duration}
end

def get_duration(input)
  command = ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_streams", input.to_s]
  streams = JSON.parse(`#{Process.quote(command)}`)["streams"].as_a
  result = streams
    .map { |i| i["duration"]? }
    .reject { |i| i.nil? }
    .map { |i| i.not_nil!.as_s.to_f }
    .min?
  if result.nil?
    tracks = JSON
      .parse(`mediainfo --Output=JSON #{input}`)["media"]["track"]
      .as_a
    result = tracks
      .map { |i| i["Duration"]? }
      .reject { |i| i.nil? }
      .map { |i| i.not_nil!.as_s.to_f }
      .min?
  end
  result
end

def encode_audio(input : Path, duration : Float, output_dir : Path)
  [encode_opus(input, duration, output_dir), encode_aac(input, duration, output_dir)]
end

def encode_video(input : Path, duration : Float, config : YAML::Any, output_dir : Path)
  storyboard(input, duration, config, output_dir)
  [encode_av1(input, duration, output_dir), encode_h264(input, duration, output_dir)]
end

def encode_av1(input : Path, duration : Float, output_dir : Path)
  temp = CACHE_DIR.join("#{input.basename}_av1.mp4")
  # profiles 8 and 11 are okay
  # https://gitlab.com/AOMediaCodec/SVT-AV1/-/blob/63c95718d14d03ef800b70ba35b875a5df9d4ac5/Docs/CommonQuestions.md#what-presets-do
  ffmpeg_encode(input, temp, "-an -vsync cfr -vcodec libsvtav1 -g 600 -preset 11 -profile main -level 4.1 -pix_fmt yuv420p")
  result = maybe_transcode_hls(temp, duration, CODEC_AV1, "video", output_dir)
  File.delete(temp)
  result
end

def encode_h264(input : Path, duration : Float, output_dir : Path)
  # bitrate 1-2M is okay
  codec = CODEC_H264
  temp = CACHE_DIR.join("#{input.basename}_#{codec}.mp4")
  ffmpeg_encode(input, temp, "-an -vsync cfr -vcodec h264_nvenc -g 600 -b:v 1M -profile:v high -level:v 4.2 -pix_fmt yuv420p")
  result = maybe_transcode_hls(temp, duration, codec, "video", output_dir)
  File.delete(temp)
  result
end

def encode_opus(input : Path, duration : Float, output_dir : Path)
  codec = CODEC_OPUS
  temp_opus = CACHE_DIR.join("#{input.basename}.#{codec}")
  temp_flac = Path["#{temp_opus}.flac"]
  temp_mp4 = Path["#{temp_opus}.mp4"]

  ffmpeg_encode(input, temp_flac, "-vn -acodec flac")
  system("opusenc --quiet --bitrate #{OPUS_BITRATE_KBPS} #{temp_flac} #{temp_opus}")
  raise "encoding opus failure" unless $?.success?
  ffmpeg_encode(temp_opus, temp_mp4, "-vn -c copy")

  result = maybe_transcode_hls(temp_mp4, duration, codec, "audio", output_dir)
  [temp_opus, temp_flac, temp_mp4].each { |i| File.delete(i) }
  result
end

def encode_aac(input : Path, duration : Float, output_dir : Path)
  codec = CODEC_AAC
  temp = CACHE_DIR.join("#{input.basename}_#{codec}.mp4")
  ffmpeg_encode(input, temp, "-vn -acodec libfdk_aac -profile:a aac_low -b:a 128k")
  result = maybe_transcode_hls(temp, duration, codec, "audio", output_dir)
  File.delete(temp)
  result
end

def storyboard(video : Path, duration : Float, config : YAML::Any, output_dir : Path)
  result = output_dir.join("storyboard.webp")
  return if nonempty_exists?(result)

  temp_dir = CACHE_DIR.join("#{video.basename}_storyboard")
  temp_frame = temp_dir.join("frame_%08d.png")
  temp_result = temp_dir.join("storyboard.png")
  Dir.mkdir_p(temp_dir)

  config = config["theme_settings"]["p2p_player"]["storyboard"]
  max_size = config["max_size"].as_i
  interval_sec = config["interval_sec"].as_i
  tile_width = config["tile_width"].as_i
  tile_height = (tile_width * (9 / 16)).to_i

  max_tiles_horizontal = (max_size / tile_width).to_i
  max_tiles_vertical = (max_size / tile_height).to_i

  frame_area = tile_width * tile_height
  max_frames = ((max_size ** 2) / frame_area).to_i

  frames = [(duration / interval_sec).to_i, max_frames].min
  size = Math.sqrt(frames * frame_area)
  tiles_horizontal = [(size / tile_width).ceil.to_i, max_tiles_horizontal].min
  tiles_vertical = [(frames / tiles_horizontal).ceil.to_i, max_tiles_vertical].min

  system(<<-STRING
    set -euo pipefail
    #{TRACE ? "set -x" : ""}
    ffmpeg -loglevel error -y -skip_frame nokey -an -i #{video} -vf 'fps=1/#{interval_sec},scale=#{tile_width}:#{tile_height}' -vsync passthrough #{temp_frame}
    ffmpeg -loglevel error -y -framerate 1 -i #{temp_frame} -filter_complex '[0]tile=#{tiles_horizontal}x#{tiles_vertical}' #{temp_result}
    cwebp -quiet -q 60 #{temp_result} -o #{result}
  STRING
  )
  raise "generating storyboard failure" unless $?.success?
  FileUtils.mv(result, output_dir.join(result.basename))
  FileUtils.rm_r(temp_dir)
end

def resolution(tracks)
  tracks
    .reject { |i| i["Width"]?.nil? || i["Height"]?.nil? }
    .map { |i| "#{i["Width"].not_nil!}x#{i["Height"].not_nil!}" }[0]
end

def bitrate(tracks, duration)
  bitrate = tracks
    .map { |i| i["OverallBitRate"]? }
    .reject { |i| i.nil? }
    .map { |i| i.not_nil!.as_s.to_i }[0]?
  if bitrate.nil?
    file_size = tracks
      .map { |i| i["FileSize"]? }
      .reject { |i| i.nil? }
      .map { |i| i.not_nil!.as_s.to_i }[0]
    bitrate = (file_size * 8) / duration.not_nil!.to_i
  end
  bitrate.ceil.to_i
end

def transcode_youtube(url : URI, config : YAML::Any, output_dir : Path, stream_type, items)
  medias = items
    .map { |formats, codec|
      {ytdlp(url, formats, codec), formats, codec}
    }
    .reject { |i, _, _| i.nil? }
  first_raw_media, _ = medias[0].not_nil!
  duration = medias
    .map { |i, _, _| get_duration(i) }
    .reject { |i| i.nil? }
    .map { |i| i.not_nil! }
    .min
  if stream_type == "video"
    storyboard(first_raw_media.not_nil!, duration, config, output_dir)
  end

  medias
    .map { |raw_media, formats, codec|
      if raw_media.nil?
        nil
      else
        temp = Path["#{raw_media}.mp4"]
        ffmpeg_encode(raw_media, temp, "-c copy")
        result = maybe_transcode_hls(temp, duration, codec, stream_type, output_dir)
        File.delete(temp)
        result
      end
    }
    .reject { |i| i.nil? }
    .map { |i| i.not_nil! }
end

def ytdlp(url : URI, formats : Array(Number), codec : String)
  output = CACHE_DIR.join("#{url.path}_#{codec}")
  unless nonempty_exists?(output)
    system("yt-dlp --no-config --verbose --format '#{formats.join('/')}' --output #{output} #{url}")
  end
  nonempty_exists?(output) ? output : nil
end

def download_youtube_thumbnail(url : URI, output_dir : Path)
  temp = CACHE_DIR.join("#{url.path}_thumbnail.jpg")
  output = output_dir.join("thumbnail.webp")
  return if nonempty_exists?(output)

  Dir.mkdir_p(output_dir, 0o755)
  webp_url = URI.parse("https://i.ytimg.com/vi_webp#{url.path}/maxresdefault.webp")
  jpeg_url = URI.parse("https://img.youtube.com/vi#{url.path}/maxresdefault.jpg")
  system(
    <<-STRING
    set -euo pipefail
    #{TRACE ? "set -x" : ""}
    wget -qO #{output} #{webp_url} && exit
    wget -qO #{temp} #{jpeg_url}
    cwebp -quiet -q 90 #{temp} -o #{output}
    STRING
  )
  raise "thumbnail failure" unless $?.success?
end

def ffmpeg_encode(input : Path, output : Path, args : String)
  command =
    <<-STRING
       ffmpeg \
         -loglevel error \
         -y \
         -threads #{System.cpu_count} \
         -fflags '+genpts+igndts' \
         -i #{input} #{args} \
         -map_metadata -1 \
         -max_muxing_queue_size 1024 \
         -shortest \
         -movflags faststart \
         -strict -2 #{output}
       STRING
  system(command)
  raise "#{command} failure" unless $?.success?
end

def git_ls(dir : Path)
  `git -C #{dir} ls-files`
    .split('\n')
    .reject { |i| i.empty? }
    .map { |i| Path[i] }
    .to_set
end

def nonempty_exists?(path : Path)
  File.file?(path) && !File.empty?(path)
end

def print_expiration(time)
  now = Time.utc
  if now < time
    if now + 30.days >= time
      warn(time)
    else
      ok(time)
    end
  else
    error(time)
  end
end

def trace(text)
  return unless TRACE
  Colorize.with.dark_gray.surround(STDOUT) do
    puts(text)
  end
end

def error(text)
  Colorize.with.red.surround(STDOUT) do
    print(text)
  end
end

def warn(text)
  Colorize.with.yellow.surround(STDOUT) do
    print(text)
  end
end

def step(text)
  Colorize.with.white.bold.surround(STDOUT) do
    puts("\n⦾ #{text}")
  end
end

def ok(text)
  Colorize.with.green.surround(STDOUT) do
    print(text)
  end
end

main
