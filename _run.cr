#!/usr/bin/env crystal

# runs CI/development cycle
# _hosts and _ohmyvps are two-directionally synchronizable

require "colorize"
require "file_utils"
require "ini"
require "json"
require "uri"
require "yaml"

DEBUG = ARGV.empty? || !["prod", "health"].includes?(ARGV[0])

MEDIA_HOST  = "media.codonaft"
MIRROR_HOST = "mirror.codonaft"

PUBLIC_MEDIA_HOST = "#{MEDIA_HOST}.com"

TARGET_CPU = "nocona" # ssh media.codonaft -- rustc --print target-cpus | grep native | sed 's!.* (currently !!;s!)\\.!!'

AQUATIC_VERSION          = "0.9.0"
BINDGEN_VERSION          = "0.70.1"
BROWSER_DETECTOR_VERSION = "4.1.0"
FRANC_VERSION            = "6.2.0"
HLS_VERSION              = "1.5.15"
P2P_MEDIA_LOADER_VERSION = "2.0.1"

CODEC_AV1  = "av01.0.09M.08.0.110.01.01.01.0"
CODEC_H264 = "avc1.64002a"
CODEC_OPUS = "opus"
CODEC_AAC  = "mp4a.40.2"

BANDWIDTH_MB_PER_SEC = 20
IGNORE_WSS           = ["personal.tracker.com", "tracker.novage.com.ua"]

HOSTS_DIR       = Path["_hosts"]
BUILD_DIR       = Path[".build"]
CACHE_DIR       = BUILD_DIR.join(".cache")
BANLISTS        = CACHE_DIR.join("banlists.txt")
COMMON_ROOT     = Path["_ohmyvps/alpine/alpine-root"]
MEDIA_BUILD_DIR = BUILD_DIR.join(MEDIA_HOST, "/var/www", PUBLIC_MEDIA_HOST)

def main
  repo_dir = Path[File.dirname(File.realpath(__FILE__))]
  Dir.cd(repo_dir)

  config = YAML.parse(File.read("_config.yml"))
  if !ARGV.empty? && (ARGV.includes?("-h") || ARGV.includes?("--help"))
    usage
  elsif ARGV.size > 2 && ARGV[0] == "encode"
    encode_media(ARGV[1], config, ARGV[2])
  elsif ARGV.size == 1 && ARGV[0] == "health"
    health(config)
  elsif ARGV.empty? || ARGV[0] == "prod"
    deploy_and_serve(config)
  else
    usage
  end
end

def usage
  script = Path["./"].join(Path.new(__FILE__).relative_to(Dir.current))
  puts(<<-STRING
          usage:
            #{script}
              build, serve jekyll in debug mode locally
            #{script} prod
              build, deploy to prod, run health checks, serve jekyll in release mode locally
            #{script} encode path/to/video-name.mkv <en|ru>
              encode media to HLS and put it to #{MEDIA_BUILD_DIR}/video-name/
            #{script} encode https://youtu.be/CB9bS46vl04 <en|ru>
              download media, encode it to HLS and put it to #{MEDIA_BUILD_DIR}/CB9bS46vl04/
            #{script} health
              run health checks
          STRING
  )
  exit 1
end

def deploy_and_serve(config)
  check
  update
  build
  sync
  start
  health(config)

  serve("localhost")
  # serve("0.0.0.0")
end

def build
  step("build")
  Dir.mkdir_p(CACHE_DIR, 0o755)
  build_vidstack_player
  build_zapthreads
  build_jekyll(MIRROR_HOST, destination: Path["/var/www/codonaft.i2p"])
  build_aquatic(MEDIA_HOST)
end

def start
  if DEBUG
    warn("skipping start")
    return
  end
  step("start")
  start_openrc(MIRROR_HOST, services: ["i2pd", "nginx"])
  start_openrc(MEDIA_HOST, services: ["aquatic_ws", "nginx"])
end

def encode_media(input : String, config : YAML::Any, language : String)
  step("encode")
  header = ["#EXTM3U", "#EXT-X-VERSION:6", "#EXT-X-INDEPENDENT-SEGMENTS"]
  audio, video =
    if input.starts_with?("https://")
      url = URI.parse(input)
      raise "unexpected url" if url.host != "youtu.be"
      output_dir = MEDIA_BUILD_DIR.join(url.path)

      download_youtube_thumbnail(url, output_dir)
      [
        transcode_youtube(url, config, output_dir, "audio", [{[251], CODEC_OPUS}, {[234], CODEC_AAC}]),
        transcode_youtube(url, config, output_dir, "video", [{[399], CODEC_AV1}, {[299, 312], CODEC_H264}]),
      ]
    else
      raw_media = Path[input]
      duration = get_duration(raw_media).not_nil!
      name = raw_media.basename.split('.')[..1][0]
      output_dir = MEDIA_BUILD_DIR.join(name)
      Dir.mkdir_p(output_dir, 0o755)
      [encode_audio(raw_media, duration, output_dir), encode_video(raw_media, duration, config, output_dir)]
    end

  audio_items = audio.map { |item|
    codec, playlist, tracks = item.not_nil!
    [
      "#EXT-X-MEDIA:TYPE=AUDIO",
      "GROUP-ID=\"#{codec}\"",
      "NAME=\"#{language}\"",
      "LANGUAGE=\"#{language}\"",
      "AUTOSELECT=YES",
      "DEFAULT=YES",
      "CHANNELS=\"2\"",
      "URI=\"#{playlist}\"",
    ].join(',')
  }

  video_items = video.cartesian_product(audio).flat_map do |video, audio|
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

  File.write(output_dir.join("main.m3u8"), (header + audio_items + video_items).join('\n'))
end

def update
  step("update")
  system(<<-STRING
    set -eu
    #{update_fonts}
    #{update_hls}
    #{update_p2p_media_loader}
    #{update_franc}
    wait
    STRING
  )
end

def sync
  if DEBUG
    warn("skipping sync")
    return
  end
  step("sync")

  puts("running sanity checks")
  [COMMON_ROOT, HOSTS_DIR].each do |dir|
    raise "Uncommited changes in #{dir}" if `git -C #{dir} status --porcelain .`.starts_with?(" M ")
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

  hosts = Dir.children(HOSTS_DIR)
  puts("hosts: #{hosts}")
  check_time(hosts)

  common_files = `git -C #{COMMON_ROOT} ls-files`
    .split('\n')
    .reject { |i| i.empty? }
    .map { |i| Path[i] }
    .to_set

  hosts.map { |host|
    done = Channel(Nil).new
    spawn do
      sync_host(host, common_files)
      done.send(nil)
    end
    done
  }.each { |i| i.receive }

  ok("sync finished")
end

def sync_host(host : String, common_files : Set(Path))
  host_dir = HOSTS_DIR.join(host)
  host_files = `git -C #{host_dir} ls-files`
    .split('\n')
    .reject { |i| i.empty? }
    .map { |i| Path[i] }
    .to_set
  two_way_sync(host, COMMON_ROOT, common_files - host_files)
  two_way_sync(host, host_dir, host_files)

  host_build_dir = BUILD_DIR.join(host)
  host_build_files = children_recursive(host_build_dir)
  two_way_sync(host, host_build_dir, host_build_files) # TODO: one way with --delete specifically for jekyll ?

  system("ssh #{host} -- sudo etckeeper commit sync 2>>/dev/null")
end

def start_openrc(host : String, *, services : Array(String))
  ssh(
    host,
    services.flat_map { |i| [
      "sudo rc-update add #{i} default",
      "sudo rc-service --ifstopped #{i} start",
      "sudo rc-service --ifcrashed #{i} restart",
    ] })
end

def ssh(host : String, stdin : Array(String))
  input = (stdin + ["exit"]).join(';')
  system("echo '#{input}' | ssh -tt #{host} /bin/sh")
end

def serve(host : String, *, destination = Path["/_site"])
  step("serve")
  output_dir = BUILD_DIR.join(host, destination)
  system("bundle exec jekyll serve --future --host #{host} --destination #{output_dir} --livereload")
end

def health(config)
  if DEBUG
    warn("skipping health")
    return
  end
  step("health")
  banlists =
    if nonempty_exists?(BANLISTS) && File.info(BANLISTS).modification_time + 1.days > Time.utc
      File.read_lines(BANLISTS).to_set
    else
      puts("updating banlists")
      update_banlists
    end

  site_url = URI.parse(config["url"].as_s)
  p2p_player_config = config["theme_settings"]["p2p_player"]
  site_hosts = find_hosts(site_url.hostname)

  stuns = p2p_player_config["ice_servers"]
    .as_a
    .map { |i| i.as_s.gsub("stun:", "").gsub(/:.*/, "") }

  cdns = `git grep --only-matching --extended-regexp "(<script.*src=|import[(]*)['\\"]*https://[a-zA-Z0-9._-]*"`
    .split('\n')
    .map { |i| i.gsub(/.*https:\/\//, "") }

  general_hosts = (site_hosts + stuns + cdns)
    .map { |i| i.strip }
    .reject { |i| i.empty? }
    .to_set

  trackers = p2p_player_config["trackers"].as_a.map { |i| URI.parse(i.as_s) }
  wss_uris = (`git grep --only-matching 'wss://[a-zA-Z0-9/._-]*'`
    .split('\n')
    .map { |i| i.strip.gsub(/.*wss:\/\//, "") }
    .reject { |i| i.empty? || IGNORE_WSS.any? { |ignored| i.includes?(ignored) } }
    .map { |i| URI.parse("wss://#{i}") } + trackers)
    .to_set

  Dir.children(HOSTS_DIR).each { |i|
    print("#{i}  ")
    check_icmp(i)
  }
  general_hosts.each { |i|
    print("#{i}  ")
    check_icmp(i)
    check_ban(i, banlists)
  }
  wss_uris.each { |i|
    print("#{i}  ")
    check_ban(i.hostname, banlists)
    check_ws(i)
  }
end

def check_icmp(host)
  output = `ping -c1 #{host} 2>>/dev/stdout | grep --extended-regexp '(^ping:|time=[0-9\\.]*)' | sed 's!.*time=!!'`.strip
  if output.starts_with?("ping:")
    error(output)
  else
    ok(output)
  end
end

def check_ws(host)
  now = Time.utc
  output = `echo -n | websocat -v #{host} 2>>/dev/stdout`
  if output.includes?("Both directions finished")
    latency = (Time.utc - now).milliseconds
    ok("#{latency} ms")
  else
    failure = output.split('\n').select { |i| i.includes?("WebSocketError") }
    error("#{host} is unavailable: #{failure}")
  end
end

def check_ban(host : String?, banlists : Set(String))
  return unless host
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
  sbc = `wget -qO - https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts || wget -qO - http://sbc.io/hosts/hosts`
    .split('\n')
    .select { |i| i.starts_with?("0.0.0.0 ") }
    .reject { |i| i == "0.0.0.0 0.0.0.0" }
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

  result = (sbc + zi)
    .map { |i| i.strip }
    .reject { |i| i.empty? }
    .to_set
  raise "banlists fetch failed" if result.empty?
  File.write(BANLISTS, result.join('\n'))
  result
end

def check
  step("check")

  # TODO
  raise("other instance keeps running") if `ps a`
                                             .split('\n')
                                             .select { |i| i.includes?("crystal") && i.includes?(__FILE__) }
                                             .any? { |i| i.split(' ')[0].to_i != Process.pid }

  if DEBUG
    warn("DEBUG")
  else
    ok("PROD")
  end

  puts("checking dependencies")
  system("which bsdtar bundle css-minify node pnpm podman rsync scour svgcleaner svgo uglifyjs wget >>/dev/null")
  raise "missing deps, run: cd && npm install 'css-minify@2.0.0' 'svgo@3.3.2' && emerge '=app-arch/libarchive-3.7.6' '=app-arch/unzip-6.0_p27-r1' '=dev-ruby/bundler-2.4.22' '=dev-lang/crystal-1.14.0' '=dev-util/uglifyjs-3.16.1' '=media-gfx/scour-0.38.2-r1' '=media-sound/opus-tools-0.2-r1' '=media-libs/libwebp-1.4.0' '=media-video/mediainfo-23.10' '=net-dns/bind-tools-9.16.50' '=net-libs/nodejs-22.4.1-r1' '=net-misc/rsync-3.3.0-r1' '=net-misc/wget-1.24.5' '=sys-apps/pnpm-bin-9.6.0' && cargo install --locked 'svgcleaner@0.9.5' 'websocat@1.13.0'" unless $?.success?

  system(<<-STRING
    set -euo pipefail
    for i in $(grep --recursive vim:nofixendofline _includes | cut -d ':' -f1) ; do
      if [[ $(wc --lines "$i" | awk '{print $1}') -ne 0 ]] ; then
        echo "unexpected newline in $i"
        exit 1
      fi
    done
    STRING
  )
  raise "file format failure" unless $?.success?
end

def build_aquatic(host : String)
  config = HOSTS_DIR.join(host, "/etc/aquatic/aquatic_ws.conf")
  bin_dir = BUILD_DIR.join(host, "/usr/local/bin")
  executable = "aquatic_ws"
  full_executable_path = bin_dir.join(executable)

  if nonempty_exists?(full_executable_path)
    warn("skipping #{full_executable_path}")
    return
  end
  Dir.mkdir_p(bin_dir, 0o755)

  alpine_version = `ssh #{host} -- cat /etc/alpine-release`.strip
  system(<<-STRING
    podman run --rm -it -v "#{bin_dir}:/build" "alpine:#{alpine_version}" /bin/sh -c "
    set -xeuo pipefail

    apk add --update --no-cache cargo clang17-libclang cmake findutils g++ git linux-headers liburing make rust

    DISABLE_AVX512=\\$(rustc --print target-features | grep '    avx512' | grep -v 'avx512fp16' | awk '{print \\$1}'  | sed 's/^/-C target-feature=-/' | xargs)
    export RUSTFLAGS=\\"-C target-cpu=#{TARGET_CPU} \\${DISABLE_AVX512} -C force-frame-pointers=y\\"
    export CFLAGS='-D_GNU_SOURCE -march=#{TARGET_CPU} -O3'
    export PATH=\\"\\${HOME}/.cargo/bin:\\${PATH}\\"

    cargo install --force --locked bindgen-cli --version '#{BINDGEN_VERSION}'
    cargo install --force --locked aquatic_ws --version '#{AQUATIC_VERSION}'
    mv ~/.cargo/bin/#{executable} /build"
  STRING
  )
end

def build_vidstack_player
  system(<<-STRING
    set -xeuo pipefail
    cd _vidstack-player
    pnpm install
    pnpm build:vidstack
    killall turbo
    rsync -a -v --delete packages/vidstack/dist-npm/cdn/with-layouts/ ../assets/js/vendor/vidstack-player/
    mkdir -p ../assets/css/vendor/vidstack-player
    cp -v packages/vidstack/dist-npm/player/styles/default/{theme.css,layouts/video.css} ../assets/css/vendor/vidstack-player/
  STRING
  )
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
end

def build_jekyll(host : String, *, destination : Path)
  prepare_jekyll
  output_dir = BUILD_DIR.join(host, destination)
  # if File.directory?(output_dir) && File.directory?("vendor")
  #   warn("skipping jekyll #{destination}")
  #   return
  # end
  Dir.mkdir_p(output_dir, 0o755)
  system("bundle exec jekyll build --future --destination #{output_dir}")
end

def prepare_jekyll
  unless File.directory?("vendor")
    FileUtils.rm_r(["Gemfile.lock", ".bundle"])
    system(<<-STRING
      set -xeuo pipefail
      gem update bundler
      gem install bundler jekyll
      bundle config set --local path 'vendor/bundle'
      bundle install
    STRING
    )
  end

  compress_options = "pure_getters"
  compress_options = "#{compress_options},drop_console" unless DEBUG

  system(<<-STRING
    set -euo pipefail

    css-minify --dir assets/css/vendor/ --output assets/css/vendor/ &

    find assets/js/partials -type f -name '*.js' -print0 | \
      sort --zero-terminated | \
      xargs -0 cat | \
      uglifyjs \
        --validate \
        --mangle \
        --compress "#{compress_options}" \
        --output assets/js/main.min.js &

    for i in $(find assets/js/vendor -name '*.js' -not -name '*.min.js' | grep -vE '/(vidstack-player|zapthreads|hls)') ; do
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
end

def update_franc
  # https://esm.sh/franc-min@6?bundle
  <<-STRING
    wget -q 'https://esm.sh/v135/franc-min@#{FRANC_VERSION}/es2022/franc-min.bundle.mjs' -O 'assets/js/vendor/franc-min.js' &
    wget -q 'https://esm.sh/v135/franc-min@#{FRANC_VERSION}/es2022/franc-min.bundle.mjs.map' -O 'assets/js/vendor/franc-min.js.map' &
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
      #for i in "p2p-media-loader-${pack}.es.js"{,.map} ; do
      for i in "p2p-media-loader-${pack}.es.js" ; do
        dest="$i"
        #if [[ "$i" == *.min.js ]]; then
        #  dest="${i%.min.js}.js"
        #fi
        wget -q "https://cdn.jsdelivr.net/npm/p2p-media-loader-${pack}@#{P2P_MEDIA_LOADER_VERSION}/dist/$i" -O "assets/js/vendor/${dest}" &
      done
    done
  STRING
end

def update_fonts
  <<-STRING
    # https://github.com/majodev/google-webfonts-helper https://gwfh.mranftl.com/fonts
    api='https://gwfh.mranftl.com/api/fonts/'

    # FIXME: https://github.com/majodev/google-webfonts-helper/issues/184
    wget 'https://fonts.gstatic.com/s/notocoloremoji/v30/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.2.woff2' -qO 'assets/fonts/noto-color-emoji-v30-emoji-regular.woff2' &

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

def rsync(source_dir : Path, files : Array(Path), args : Array(String))
  files_from = CACHE_DIR.join("sync-#{source_dir.to_s.gsub('/', '_')}.txt")
  File.write(files_from, files.join('\n'))
  system("cd #{source_dir} && rsync --rsync-path='sudo /usr/bin/rsync' --bwlimit=#{BANDWIDTH_MB_PER_SEC}m --archive --no-perms --no-group --no-owner --chmod=go-w --itemize-changes --update --checksum --compress --sparse --files-from=#{File.expand_path(files_from)} #{Process.quote(args)}")
end

def two_way_sync(host : String, local_dir : Path, files : Enumerable(Path))
  return if files.empty? || !Dir.exists?(local_dir)

  filtered_files = files.reject { |i|
    dir = i.parts[0]
    dir == "home" || i == Path["etc/conf.d/nginx"]
  }

  rsync(local_dir, filtered_files, ["#{host}:/", "./"])
  rsync(local_dir, filtered_files, ["./", "#{host}:/"])
end

def check_time(hosts : Array(String))
  hosts_out_of_sync = hosts
    .map { |host|
      out_of_sync = Channel(Bool).new
      spawn do
        remote_now = Time.unix(`ssh #{host} -- date --utc +%s`.to_i)
        now = Time.utc
        dt = remote_now - now
        out_of_sync.send(dt.abs > 2.seconds)
      end
      {host, out_of_sync}
    }
    .select { |_, out_of_sync| out_of_sync.receive }
    .map { |host, _| host }
  raise "#{hosts_out_of_sync} time is out of sync" unless hosts_out_of_sync.empty?
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

def maybe_transcode_hls(input : Path | Nil, duration : Float, codec, stream_type, output_dir : Path)
  return nil unless input

  segment_type = [CODEC_H264, CODEC_AAC].includes?(codec) ? "mpegts" : "fmp4"

  stream_output_dir = output_dir.join(codec)
  Dir.mkdir_p(stream_output_dir, 0o755)

  playlist_m3u8 = "#{stream_type}.m3u8"
  temp_playlist_m3u8 = "temp.m3u8"
  template = stream_output_dir.join("%08d.ts")
  playlist = stream_output_dir.join(playlist_m3u8)

  system(
    <<-STRING
      ffmpeg \
        -loglevel error \
        -y \
        -fflags '+genpts+igndts' \
        -i '#{input}' \
        -c copy \
        -movflags faststart \
        -pix_fmt yuv420p \
        -f hls \
        -g 48 \
        -keyint_min 48 \
        -sc_threshold 0 \
        -hls_time 4 \
        -hls_playlist_type vod \
        -hls_segment_type #{segment_type} \
        -master_pl_name #{temp_playlist_m3u8} \
        -hls_segment_filename #{template} #{playlist}
    STRING
  )

  raise "failed to transcode #{playlist}" unless $?.success?

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
  # [encode_av1(input, duration, output_dir), encode_h264(input, duration, output_dir)] # FIXME: av1 is out of sync
  [encode_h264(input, duration, output_dir)]
end

def encode_av1(input : Path, duration : Float, output_dir : Path)
  temp = CACHE_DIR.join("#{input.basename}_av1.mp4")
  system("ffmpeg -loglevel error -y -threads #{System.cpu_count} -fflags '+genpts+igndts' -i #{input} -an -vcodec libsvtav1 -b:v 0 -preset 8 -profile main -level 4.1 -g 300 -pix_fmt yuv420p -strict -2 #{temp}")
  raise "encoding av1 failed" unless $?.success?
  result = maybe_transcode_hls(temp, duration, CODEC_AV1, "video", output_dir)
  File.delete(temp)
  result
end

def encode_h264(input : Path, duration : Float, output_dir : Path)
  codec = CODEC_H264
  temp = CACHE_DIR.join("#{input.basename}_#{codec}.mp4")
  system("ffmpeg -loglevel error -y -threads #{System.cpu_count} -fflags '+genpts+igndts' -i #{input} -an -vcodec h264_nvenc -profile:v high -level:v 4.2 -b:v 5M -pix_fmt yuv420p -movflags faststart -strict -2 #{temp}")
  raise "encoding h264 failed" unless $?.success?
  result = maybe_transcode_hls(temp, duration, codec, "video", output_dir)
  File.delete(temp)
  result
end

def encode_opus(input : Path, duration : Float, output_dir : Path)
  codec = CODEC_OPUS
  temp_opus = CACHE_DIR.join("#{input.basename}.#{codec}")
  temp_flac = Path["#{temp_opus}.flac"]
  temp_webm = Path["#{temp_opus}.webm"]
  system(
    <<-STRING
       set -euo pipefail
       ffmpeg -loglevel error -y -fflags '+genpts+igndts' -i #{input} -vn -movflags faststart -strict -2 #{temp_flac}
       opusenc --quiet --bitrate 510 #{temp_flac} #{temp_opus}
       ffmpeg -loglevel error -y -fflags '+genpts+igndts' -i #{temp_opus} -c copy -movflags faststart -strict -2 #{temp_webm}
       STRING
  )
  raise "encoding opus failed" unless $?.success?
  result = maybe_transcode_hls(temp_webm, duration, codec, "audio", output_dir)
  [temp_opus, temp_flac, temp_webm].each { |i| File.delete(i) }
  result
end

def encode_aac(input : Path, duration : Float, output_dir : Path)
  codec = CODEC_AAC
  temp = CACHE_DIR.join("#{input.basename}_#{codec}.m4a")
  # system("ffmpeg -loglevel error -y -threads #{System.cpu_count} -fflags '+genpts+igndts' -i #{input} -vn -acodec aac -profile:a lc -b:a 128k -movflags faststart -strict -2 #{temp}")
  system("ffmpeg -loglevel error -y -threads #{System.cpu_count} -fflags '+genpts+igndts' -i #{input} -vn -acodec libfdk_aac -profile:a aac_low -b:a 128k -movflags faststart -strict -2 #{temp}")
  raise "encoding aac failed" unless $?.success?
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

  frames = [(duration / interval_sec).ceil.to_i, max_frames].min
  size = Math.sqrt(frames * frame_area)
  tiles_horizontal = [(size / tile_width).ceil.to_i, max_tiles_horizontal].min
  tiles_vertical = [(frames / tiles_horizontal).ceil.to_i, max_tiles_vertical].min

  system(<<-STRING
    set -euo pipefail
    ffmpeg -loglevel error -y -skip_frame nokey -i #{video} -vf 'fps=1/#{interval_sec},scale=#{tile_width}:#{tile_height}' -an -vsync passthrough #{temp_frame}
    ffmpeg -loglevel error -y -framerate 1 -i #{temp_frame} -filter_complex '[0]tile=#{tiles_horizontal}x#{tiles_vertical}' #{temp_result}
    cwebp -quiet -q 60 #{temp_result} -o #{result}
  STRING
  )
  raise "generating storyboard failed" unless $?.success?
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
      maybe_transcode_hls(raw_media, duration, codec, stream_type, output_dir)
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
    wget -qO #{output} #{webp_url} && exit
    wget -qO #{temp} #{jpeg_url}
    cwebp -quiet -q 90 #{temp} -o #{output}
    STRING
  )
  raise "thumbnail failure" unless $?.success?
end

def nonempty_exists?(path : Path)
  File.file?(path) && !File.empty?(path)
end

def error(text)
  Colorize.with.red.surround(STDOUT) do
    puts(text)
  end
end

def warn(text)
  Colorize.with.yellow.surround(STDOUT) do
    puts(text)
  end
end

def step(text)
  Colorize.with.white.bold.surround(STDOUT) do
    puts("\n⦾ #{text}")
  end
end

def ok(text)
  Colorize.with.green.surround(STDOUT) do
    puts(text)
  end
end

main
