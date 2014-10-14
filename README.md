# etcd-toucher

`etcd-toucher` is a long-lived process that watches one etcd key and touches another on change.

## Usage

Configuration is performed through environment variables.

* `TOUCH_KEY` - The etcd key to touch when the watched key is changed (mandatory, no default).
* `WATCH_KEY` - The etcd key to watch (mandatory, no default).
* `WATCH_ACTION` - If set, only etcd actions (e.g. `set`) of this type are considered (default: unset).
* `WATCH_RECURSIVE` - If set, the watch is recursive (default: unset).
* `ETCD_PEERS` - A whitespace-delimited list of one or more etcd peer URLs (default: `http://127.0.0.1:4001`).
* `ETCD_PORT_4001_TCP_ADDR` - The address of an etcd peer if `ETCD_PEERS` is not given (default: `127.0.0.1`).
* `ETCD_PORT_4001_TCP_PORT` - The port of an etcd peer if `ETCD_PEERS` is not given (default: `4001`).

## Examples

The following docker process is used to touch a redis master/slave topology when its SkyDNS keys change. This
allows an `etcd-observer` to resend the topology to a `redis-dictator` when redis instances are rescheduled
and change IP addresses. Note that `WATCH_ACTION` is used to ignore deletes, so that container restarts only
resend the topology when the container starts.

```
docker run -d \
	--link etcd:etcd \
	-e WATCH_KEY=/skydns/docker/redis-1 \
	-e WATCH_RECURSIVE=yes \
	-e WATCH_ACTION=set \
	-e TOUCH_KEY=/config/redis-1/topology \
	sheldonh/etcd-observer
```
