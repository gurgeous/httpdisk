require "content-type"
require "faraday"
require "logger"

module HTTPDisk
  # Middleware and main entry point.
  class Client < Faraday::Middleware
    attr_reader :cache, :options

    def initialize(app, options = {})
      options = Sloptions.parse(options) do
        _1.string :dir, default: File.join(ENV["HOME"], "httpdisk")
        _1.integer :expires
        _1.boolean :force
        _1.boolean :force_errors
        _1.array :ignore_params, default: []
        _1.on :logger, type: [:boolean, Logger]
        _1.boolean :utf8
      end

      super(app, options)
      @cache = Cache.new(options)
    end

    def call(env)
      cache_key = CacheKey.new(env, ignore_params:)
      logger&.info("#{env.method.upcase} #{env.url} (#{cache.status(cache_key)})")
      env[:httpdisk_diskpath] = cache.diskpath(cache_key)

      # check cache, fallback to network
      if (response = read(cache_key, env))
        response.env[:httpdisk] = true
      else
        response = perform(env)
        response.env[:httpdisk] = false
        write(cache_key, env, response)
      end

      encode_body(response)
      response
    end

    # Returns cache status for this request
    def status(env)
      cache_key = CacheKey.new(env)
      {
        url: env.url.to_s,
        status: cache.status(cache_key).to_s,
        key: cache_key.key,
        digest: cache_key.digest,
        path: cache.diskpath(cache_key)
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
        _1.response_body = ""
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

    # Set string encoding for response body. The cache always returns
    # ASCII-8BIT, but we have no idea what the encoding will be from the
    # network. Not all adapters honor Content-Type (including the default
    # adapter).
    def encode_body(response)
      body = response.body || ""

      # parse Content-Type
      begin
        content_type = response["Content-Type"] && ContentType.parse(response["Content-Type"])
      rescue Parslet::ParseFailed
        # unparsable
      end

      # look at charset and set body encoding if necessary
      encoding = encoding_for(content_type)
      if body.encoding != encoding
        body = body.dup if body.frozen?
        body.force_encoding(encoding)
      end

      # if :utf8, force body to UTF-8
      if options[:utf8] && content_type && response_text?(content_type)
        body = body.dup if body.frozen?
        begin
          body.encode!("UTF-8", invalid: :replace, undef: :replace, replace: "?")
        rescue Encoding::ConverterNotFoundError
          # rare, can't do anything here
          body = "httpdisk could not convert from #{body.encoding.name} to UTF-8"
        end
      end

      response.env[:body] = body
    end

    def encoding_for(content_type)
      if content_type&.charset
        begin
          return Encoding.find(content_type.charset)
        rescue ArgumentError
          # unknown charset
        end
      end
      Encoding::ASCII_8BIT
    end

    def response_text?(content_type)
      content_type.type == "text" || content_type.mime_type == "application/json"
    end

    #
    # options
    #

    def ignore_params
      @ignore_params ||= options[:ignore_params].map { CGI.escape(_1.to_s) }.to_set
    end

    def logger
      return if !options[:logger]

      @logger ||= case options[:logger]
      when true then Logger.new($stderr)
      when Logger then options[:logger]
      end
    end
  end
end

# register
Faraday::Middleware.register_middleware(httpdisk: HTTPDisk::Client)
