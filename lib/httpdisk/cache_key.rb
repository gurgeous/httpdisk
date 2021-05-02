require 'cgi'
require 'digest/md5'
require 'uri'

module HTTPDisk
  class CacheKey
    attr_reader :env

    def initialize(env)
      @env = env

      # sanity checks
      raise 'http/https required' if env.url.scheme !~ /^https?$/
      raise 'hostname required' if !env.url.host
    end

    def url
      env.url
    end

    # Cache key (memoized)
    def key
      @key ||= calculate_key
    end

    # md5(key) (memoized)
    def digest
      @digest ||= Digest::MD5.hexdigest(key)
    end

    # Relative path for this cache key based on hostdir & digest.
    def diskpath
      @diskpath ||= File.join(hostdir, digest[0, 3], digest[3..])
    end

    def to_s
      key
    end

    protected

    # Calculate cache key for url
    def calculate_key
      key = []
      key << env.method.upcase
      key << ' '
      key << url.scheme
      key << '://'
      key << url.host.downcase
      if !default_port?
        key << ':'
        key << url.port
      end
      if url.path != '/'
        key << url.path
      end
      if (q = url.query) && q != ''
        key << '?'
        key << querykey(q)
      end
      if env.request_body
        key << ' '
        key << bodykey
      end
      key.join
    end

    # Calculate cache key segment for body
    def bodykey
      body = env.request_body.to_s
      if env.request_headers['Content-Type'] == 'application/x-www-form-urlencoded'
        querykey(body)
      elsif body.length < 50
        body
      else
        Digest::MD5.hexdigest(body)
      end
    end

    # Calculate canonical key for a query
    def querykey(q)
      q.split('&').sort.join('&')
    end

    def default_port?
      url.default_port == url.port
    end

    # Calculate nice directory name from url.host
    def hostdir
      hostdir = url.host.downcase
      hostdir = hostdir.gsub(/^www\./, '')
      hostdir = hostdir.gsub(/[^a-z0-9._-]/, '')
      hostdir = hostdir.squeeze('.')
      hostdir = 'any' if hostdir.empty?
      hostdir
    end
  end
end
