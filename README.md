[![Build Status](https://github.com/gurgeous/httpdisk/workflows/test/badge.svg?branch=main)](https://github.com/gurgeous/httpdisk/actions)

![logo](logo.svg)

# httpdisk

httpdisk is an aggressive disk cache built on top of [Faraday](https://lostisland.github.io/faraday/). It's primarily used for crawling, and will aggressively cache all requests including POSTs and transient errors.

## Installation

```sh
# install gem
$ gem install httpdisk

# or add to your Gemfile
gem 'httpdisk'
```

## Quick Start

```ruby
require 'httpdisk'

# create a new Faraday client
faraday = Faraday.new do
  _1.use :httpdisk
end

response = faraday.get('https://google.com') # read from network
response = faraday.get('https://google.com') # read from ~/httpdisk/google.com/...
```

httpdisk includes a handy command that works like `curl`:

```sh
# cache miss, read from network
$ httpdisk google.com

# cache hit, read from ~/httpdisk/google.com/...
$ httpdisk google.com

# supports many curl flags
$ httpdisk -A test-agent --proxy localhost:8080 --output tmp.html twitter.com
```

## Faraday & httpdisk

[Faraday](https://lostisland.github.io/faraday/) is a popular Ruby HTTP client. Faraday uses a stack of middleware to process each request, similar to the way Rack works deep inside Rails or Sinatra. httpdisk is Faraday middleware - it processes requests to look for cached responses on disk. Faraday's [usage page](https://lostisland.github.io/faraday/usage/) is a good place to learn more about Faraday.

The simplest possible setup for httpdisk looks like this:

```ruby
faraday = Faraday.new do
  _1.use :httpdisk
end
faraday.get(...)
```

For serious crawling, you probably want a more robust middleware stack:

```ruby
faraday = Faraday.new do
  _1.options.timeout = 10 # lower the timeout
  _1.use :cookie_jar # cookie support
  _1.request :url_encoded # auto-encode form bodies
  _1.response :json # auto-decode JSON responses
  _1.response :follow_redirects # follow redirects (should be above httpdisk)
  _1.response :encoding # set Ruby string encoding based on Content-Type (should be above httpdisk)
  _1.use :httpdisk
  _1.request :retry # retry failed responses (should be below httpdisk)
end
faraday.get(...)
```

You may want to experiment with the options for [:retry](https://lostisland.github.io/faraday/middleware/retry), to retry a
broader set of transient errors. See [examples.rb](https://github.com/gurgeous/httpdisk/blob/main/examples.rb) for more ideas.

## Disk Cache

httpdisk calculates a canonical cache key for each request. The key consists of the http method, url, sorted query, and sorted body if possible. We use md5(key) as the path for each file in the cache. Try `httpdisk --status` to see it in action:

```sh
$ httpdisk --status "google.com?q=ruby"
url: "http://google.com/?q=ruby"
status: "miss"
key: "GET http://google.com?q=ruby"
digest: "0e37f96800a55958fa6029283c78f672"
path: "httpdisk/google.com/0e3/7f96800a55958fa6029283c78f672"
```

EVERY response will be cached on disk, including POSTs. By default, the cache will be placed at `~/httpdisk` and cached responses never expire. Some examples:

```ruby
faraday.get("http://www.google.com", nil, { "User-Agent": "test-agent" })
faraday.get("http://www.google.com", { "q": "ruby" })
faraday.post("http://httpbin.org/post", "name=hello")
```

This will populate the cache:

```sh
$ cd ~/httpdisk
$ find . -type f
./google.com/5eb/fc70198242876f5e83a67253663e9
./google.com/6d0/52ac9a33d25065fc9f405100f3741
./httpbin.org/88f/7b2bc35cc3759c9905c4de1dbf981

$ gzcat google.com/5eb/fc70198242876f5e83a67253663e9
# GET http://www.google.com
HTTPDISK 200 OK
date: Mon, 19 Apr 2021 18:40:01 GMT
expires: -1
cache-control: private, max-age=0
...
```

## Aggressive Caching

httpdisk caches all responses. POST responses are cached, along with 500 responses and other HTTP errors. HTTP response headers that typically control caching are completely ignored. We also cache many exceptions like connection refused, timeout, ssl error, etc. These are returned as responses with HTTP status code 999.

In general, if you make a request it will be cached regardless of the outcome.

## Configuration

httpdisk supports a few options:

- `dir:` location for disk cache, defaults to `~/httpdisk`
- `expires_in:` when to expire cached requests, default is nil (never expire)
- `force:` don't read anything from cache (but still write)
- `force_errors:` don't read errors from cache (but still write)
- `ignore_params:` array of query params to ignore when calculating cache_key
- `logger`: log requests to stderr, or pass your own logger

Pass these in when setting up Faraday:

```ruby
faraday = Faraday.new do
  _1.use :httpdisk, expires_in: 7*24*60*60, force: true
end
```

## Command Line

The `httpdisk` command works like `curl` and supports some of curl's popular flags. Exit code 1 indicates an HTTP response code >= 400 or a failed request.

```
$ httpdisk --help
httpdisk [options] [url]
Similar to curl:
    -d, --data        HTTP POST data
    -H, --header      pass custom header(s) to server
    -i, --include     include response headers in the output
    -m, --max-time    maximum time allowed for the transfer
    -o, --output      write to file instead of stdout
    -x, --proxy       use host[:port] as proxy
    -X, --request     HTTP method to use
    --retry           retry request if problems occur
    -s, --silent      silent mode (don't print errors)
    -A, --user-agent  send User-Agent to server
Specific to httpdisk:
    --dir             httpdisk cache directory (defaults to ~/httpdisk)
    --expires         when to expire cached requests (ex: 1h, 2d, 3w)
    --force           don't read anything from cache (but still write)
    --force-errors    don't read errors from cache (but still write)
    --status          show status for a url in the cache
    --version         show version
    --help            show this help
```

## Limitations & Gotchas

- Transient errors are cached. This is appropriate for many uses cases (like crawling) but can be confusing. Use `httpdisk --status` to debug.
- There are no builtin mechanisms to cleanup or limit the size of the cache. Use `rm`
- For best results the `:follow_redirects` middleware should be listed _above_ httpdisk. That way each redirect request will be cached.
- For best results the `:retry` middleware should be listed _below_ httpdisk. That way retries will complete before we cache.
- httpdisk does not work with Faraday's parallel mode or `on_complete`.

## Changelog

#### 0.3 (unreleased)

- added :ignore_params, for ignoring query params when generating cache keys
- HTTP 50x responses return :error status (and respond to `force_error`)

#### 0.2 - May 2020

- added `response.env[:httpdisk]`, which will be true if the response came from the cache
- added `:logger` option
- rake rubocop

#### 0.1 - April 2020

- Original release
