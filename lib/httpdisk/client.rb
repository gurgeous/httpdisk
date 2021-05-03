require 'faraday'
require 'logger'

module HTTPDisk
  DEFAULTS = {
    dir: File.join(ENV['HOME'], 'httpdisk'),
    expires_in: nil,
    force: false,
    force_errors: false,
    ignore_params: [],
    logger: false,
  }.freeze

  SCHEMA = {
    dir: String,
    expires_in: [nil, Integer],
    force: :boolean,
    force_errors: :boolean,
    ignore_params: [Array],
    logger: [:boolean, Logger],
  }.freeze

  # Middleware and main entry point.
  class Client < Faraday::Middleware
    attr_reader :cache, :options

    def initialize(app, options = {})
      super(app, options = DEFAULTS.merge(options.compact))
      Sanity.new(options, SCHEMA).check!

      @cache = Cache.new(options)
    end

    def call(env)
      cache_key = CacheKey.new(env, ignore_params: ignore_params)
      logger&.info("#{env.method.upcase} #{env.url} (#{cache.status(cache_key)})")

      if cached_response = read(cache_key, env)
        cached_response.env[:httpdisk] = true
        return cached_response
      end

      # miss
      perform(env).tap do |response|
        response.env[:httpdisk] = false
        write(cache_key, env, response)
      end
    end

    # Returns cache status for this request
    def status(env)
      cache_key = CacheKey.new(env)
      {
        url: env.url.to_s,
        status: cache.status(cache_key).to_s,
        key: cache_key.key,
        digest: cache_key.digest,
        path: cache.diskpath(cache_key),
      }
    end

    protected

    # perform the request, return Faraday::Response
    def perform(env)
      app.call(env)
    rescue Faraday::ConnectionFailed, Faraday::SSLError, Faraday::TimeoutError => e
      # try to avoid caching proxy errors
      raise e if proxy_error?(env, e)

      stuff_999_response(env, e)
    end

    # read from cache return Faraday::Response
    def read(cache_key, env)
      payload = cache.read(cache_key)
      return if !payload

      env.tap do
        _1.reason_phrase = payload.reason_phrase
        _1.response_body = payload.body
        _1.response_headers = payload.headers
        _1.status = payload.status
      end
      Faraday::Response.new(env)
    end

    # write Faraday::Response to cache
    def write(cache_key, env, response)
      payload = Payload.from_response(response).tap do
        _1.comment = "#{env.method.upcase} #{env.url}"
      end
      cache.write(cache_key, payload)
    end

    # stuff a 999 error into env and create a Faraday::Response
    def stuff_999_response(env, err)
      env.tap do
        _1.reason_phrase = "#{err.class} #{err.message}"
        _1.response_body = ''
        _1.response_headers = Faraday::Utils::Headers.new
        _1.status = HTTPDisk::ERROR_STATUS
      end
      Faraday::Response.new(env)
    end

    def proxy_error?(env, err)
      proxy = env.request.proxy
      return if !proxy
      return if !err.is_a?(Faraday::ConnectionFailed)

      err.to_s =~ /#{proxy.host}.*#{proxy.port}/
    end

    #
    # options
    #

    def ignore_params
      @ignore_params ||= options[:ignore_params].map { CGI.escape(_1.to_s) }.to_set
    end

    def logger
      return if !options[:logger]
      return @logger if defined?(@logger)

      @logger = case options[:logger]
      when nil, false then nil
      when true then Logger.new($stderr)
      when Logger then options[:logger]
      end
    end
  end
end

# register
Faraday::Middleware.register_middleware(httpdisk: HTTPDisk::Client)
