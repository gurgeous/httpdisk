require "cgi"
require "digest/md5"
require "uri"

module HTTPDisk
  class CacheKey
    attr_accesor :env, :ignore_params, :http_method, :scheme, :host, :port, :path, :query, :body

    def initialize(env, ignore_params: [])
      @env, @ignore_params = env, ignore_params

      # sanity checks
      raise InvalidUrl, "http/https required #{env.url.inspect}" if !/^https?$/.match?(env.url.scheme)
      raise InvalidUrl, "hostname required #{env.url.inspect}" if !env.url.host

      # this is our default key - the user can override, though
      @http_method = env.method.upcase
      @scheme = url.scheme
      @host = url.host.downcase
      @port = default_port? ? nil : url.port
      @path = (url.path == "/") ? nil : url.path
      @query = canonical_query(url.query)
      @body = env.request_body ? bodykey : nil
    end

    def query_params
      return {} if blank?(@query)

      CGI.parse(@query).transform_values do
        (_1.length == 1) ? _1.first : _1
      end
    end

    # Calculate cache key from normalized parts
    def key
      key = []
      key << http_method
      key << " "
      key << scheme
      key << "://"
      key << host
      if port
        key << ":"
        key << port
      end
      if path
        key << path
      end
      if query
        key << "?"
        key << query
      end
      if body
        key << " "
        key << body
      end
      key.join
    end

    # one-liners
    def blank?(value) = value.nil? || value == ""
    def default_port? = url.default_port == url.port
    def digest = Digest::MD5.hexdigest(key)
    def diskpath = File.join(hostdir, digest[0, 3], digest.drop(3))
    def host=(value) = @host = value&.downcase
    def http_method=(value) = @http_method = value.to_s.upcase
    def path=(value) = @path = (blank?(value) || value == "/") ? nil : value
    def query=(value) = @query = canonical_query(value)
    def query_params=(value) = self.query = URI.encode_www_form(flatten_query_params(value))
    def scheme=(value) = @scheme = value&.to_s
    def to_s = key
    def url = env.url

    protected

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
