#!/usr/bin/env ruby

require 'logger'
require 'net/http'

require 'rubygems'
require 'etcd'
require 'json'

LOG_LEVELS = {
  "fatal" => Logger::FATAL,
  "error" => Logger::ERROR,
  "warn"  => Logger::WARN,
  "info"  => Logger::INFO,
  "debug" => Logger::DEBUG
}

def get_peers_from_env(env)
  if env['ETCD_PEERS']
    env['ETCD_PEERS'].split.map do |peer|
      p = peer.dup
      peer.gsub!(/http(s?):\/\//, '')
      if $1 == "s"
        $logger.fatal "etcd SSL not currently supported"
        exit(1)
      end
      peer.gsub!(/\/.*/, '')
      host, port = peer.split(':')
      {host: host, port: port}
    end
  else
    [ {host: env['ETCD_PORT_4001_TCP_ADDR'], port: env['ETCD_PORT_4001_TCP_PORT']} ]
  end
end

def get_etcd
  Etcd.client(get_peers_from_env(ENV).sample)
end

def mapdir(r)
  m = {}
  r.node.children.each do |c|
    m[c.key] = c.value
  end
  m
end

def node_changed?(map, node)
  map[node.key] != node.value
end

recursive = !!ENV['WATCH_RECURSIVE']
watch_key = ENV['WATCH_KEY'] or raise "no WATCH_KEY given"
only_action = ENV['WATCH_ACTION']
touch_key = ENV['TOUCH_KEY'] or raise "no TOUCH_KEY given"

$logger = Logger.new($stderr)
$logger.level = LOG_LEVELS[ENV['LOG_LEVEL'] || "info"]

begin
  etcd = get_etcd
  if recursive
    map = mapdir(etcd.get(watch_key, recursive: true))
  else
    n = etcd.get(watch_key).node
    map = {n.key => n.value}
  end
  $logger.info "watching #{watch_key} (recursive: #{recursive})"

  loop do
    $logger.debug "watching #{watch_key} (recursive: #{recursive})"
    r = etcd.watch(watch_key, recursive: recursive)
    if only_action and r.action != only_action
      $logger.debug "ignoring #{r.action} on #{r.node.key}"
      next
    end
    watch = r.node
    if !node_changed?(map, watch)
      $logger.debug "ignoring unchanged value of #{watch.key}"
    else
      $logger.debug "touching #{touch_key} because #{watch.key} changed"
      begin
        o = etcd.get(touch_key).node
        r = etcd.set(touch_key, prevIndex: o.modified_index, value: o.value)
        map[watch.key] = watch.value
        $logger.info "touched #{touch_key} because #{watch.key} changed"
      rescue Etcd::TestFailed => e
        $logger.warn "compare and swap failed touching #{touch_key}, retrying..."
        sleep 1
        retry
      end
    end
  end
rescue Exception => e
  if e.is_a?(SignalException) or e.is_a?(SystemExit)
    raise
  else
    $logger.error "#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    sleep 1
  end
end
