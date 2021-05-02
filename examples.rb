#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(__dir__, 'lib'))

require 'httpdisk'
require 'json'

class Examples
  #
  # Very simple example. The only middleware is httpdisk.
  #

  def simple
    faraday = Faraday.new do
      _1.use :httpdisk, force: true
    end

    faraday.get('http://www.google.com', nil, { "User-Agent": 'test-agent' })
    faraday.get('http://www.google.com', { q: 'ruby' })
    faraday.post('http://httpbin.org/post', 'name=hello')

    3.times { puts }
    response = faraday.get('http://httpbingo.org/get')
    puts response.env.url
    puts JSON.pretty_generate(JSON.parse(response.body))
  end

  #
  # Complete Faraday stack with cookies, redirects, retries, form encoding &
  # JSON response parsing.
  #

  def better
    faraday = Faraday.new do
      # options
      _1.headers['User-Agent'] = 'HTTPDisk'
      _1.params.update(hello: 'world')
      _1.options.timeout = 10

      # middleware
      _1.use :cookie_jar
      _1.request :url_encoded
      _1.response :json
      _1.response :follow_redirects # must come before httpdisk

      # httpdisk
      _1.use :httpdisk

      # retries (must come after httpdisk)
      retry_options = {
        methods: %w[delete get head options patch post put trace],
        retry_statuses: (400..600).to_a,
        retry_if: ->(_env, _err) { true },
      }.freeze
      _1.request :retry, retry_options
    end

    # get w/ params
    3.times { puts }
    response = faraday.get('http://httpbingo.org/get', { q: 'query' })
    puts response.env.url
    puts JSON.pretty_generate(response.body)

    # post w/ encoded form body
    3.times { puts }
    response = faraday.post('http://httpbingo.org/post', 'a=1&b=2')
    puts response.env.url
    puts JSON.pretty_generate(response.body)

    # post w/ auto-encoded form hash
    3.times { puts }
    response = faraday.post('http://httpbingo.org/post', { input: 'body' })
    puts response.env.url
    puts JSON.pretty_generate(response.body)
  end

  #
  # Complete Faraday stack with cookies, redirects, retries, JSON encoding &
  # JSON response parsing.
  #

  def json
    faraday = Faraday.new do
      # options
      _1.headers['User-Agent'] = 'HTTPDisk'
      _1.params.update(hello: 'world')
      _1.options.timeout = 10

      # middleware
      _1.use :cookie_jar
      _1.request :json
      _1.response :json
      _1.response :follow_redirects # must come before httpdisk

      # httpdisk
      _1.use :httpdisk

      # retries (must come after httpdisk)
      retry_options = {
        methods: %w[delete get head options patch post put trace],
        retry_statuses: (400..600).to_a,
        retry_if: ->(_env, _err) { true },
      }.freeze
      _1.request :retry, retry_options
    end

    3.times { puts }
    response = faraday.post('http://httpbingo.org/post', { this_is: ['json'] })
    puts response.env.url
    puts JSON.pretty_generate(response.body)
  end
end

Examples.new.simple
Examples.new.better
Examples.new.json
