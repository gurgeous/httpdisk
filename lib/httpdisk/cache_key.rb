require "cgi"
require "digest/md5"
require "uri"

module HTTPDisk
  class CacheKey
    PARTS = %i[http_method scheme host port path query body].freeze

    attr_accessor :env, :ignore_params
    attr_reader(*PARTS)

    def initialize(env, ignore_params: [])
      @env, @ignore_params = env, ignore_params

      # setup defaults, user can override
      @http_method = env.method
      @scheme = url.scheme
      @host = url.host
      @port = default_port? ? nil : url.port
      @path = (url.path == "/") ? nil : url.path
      @query = url.query
      @body = env.request_body ? bodykey : nil

      # sanity checks
      raise InvalidUrl, "http/https required #{env.url.inspect}" if !/^https?$/.match?(scheme)
      raise InvalidUrl, "hostname required #{env.url.inspect}" if !host
    end

    def query_params
      return {} if blank?(query)

      CGI.parse(query).transform_values do
        (_1.length == 1) ? _1.first : _1
      end
    end

    # one-liners
    def blank?(value) = value.nil? || value == ""
    def default_port? = url.default_port == url.port
    def digest = @digest ||= Digest::MD5.hexdigest(key)
    def diskpath = @diskpath ||= File.join(hostdir, digest[0, 3], digest[3..])
    def invalidate! = @digest = @key = @diskpath = nil
    def key = @key ||= key0
    def to_s = key
    def url = env.url

    def query_params=(value)
      self.query = URI.encode_www_form(flatten_query_params(value))
    end

    # the parts that feed into `key` invalidate memoized stuff
    PARTS.each do |part|
      define_method("#{part}=") do |value|
        invalidate!
        instance_variable_set(:"@#{part}", value)
      end
    end

    protected

    def key0
      key = []
      key << http_method.to_s.upcase
      key << " "
      key << scheme.to_s
      key << "://"
      key << host.downcase
      if port
        key << ":"
        key << port
      end
      if (path = (blank?(self.path) || self.path == "/") ? nil : self.path)
        key << path
      end
      if (query = canonical_query(self.query))
        key << "?"
        key << query
      end
      body = if env.request_headers["Content-Type"] == "application/x-www-form-urlencoded"
        canonical_query(self.body)
      else
        self.body
      end
      if body
        key << " "
        key << body
      end
      key.join
    end

    # Calculate cache key segment for body
    def bodykey
      body = env.request_body.to_s
      if env.request_headers["Content-Type"] == "application/x-www-form-urlencoded"
        canonical_query(body)
      elsif body.length < 50
        body
      else
        Digest::MD5.hexdigest(body)
      end
    end

    def canonical_query(q)
      return if blank?(q)

      parts = q.split("&").sort
      if !ignore_params.empty?
        parts = parts.filter_map do |part|
          key, value = part.split("=", 2)
          next if ignore_params.include?(key)

          "#{key}=#{value}"
        end
      end
      query = parts.join("&")
      (query == "") ? nil : query
    end

    # Calculate nice directory name from url.host
    def hostdir
      hostdir = host.downcase
      hostdir = hostdir.gsub(/^www\./, "")
      hostdir = hostdir.gsub(/[^a-z0-9._-]/, "")
      hostdir = hostdir.squeeze(".")
      hostdir = "any" if hostdir.empty?
      hostdir
    end

    def flatten_query_params(value)
      value.flat_map do |k, v|
        if v.is_a?(Array)
          v.map { [k, _1] }
        else
          [[k, v]]
        end
      end
    end
  end
end
