require 'fileutils'

module HTTPDisk
  # Disk cache for cache_keys => response. Files are compressed.
  class Cache
    attr_reader :options

    def initialize(options)
      @options = options
    end

    %i[dir expires_in force force_errors].each do |method|
      define_method(method) do
        options[method]
      end
    end
    alias force? force
    alias force_errors? force_errors

    # Get cached response. If there is a cached error it will be raised.
    def read(cache_key)
      payload_or_status = read0(cache_key)
      payload_or_status.is_a?(Symbol) ? nil : payload_or_status
    end

    # Cache status for a cache_key, %i[error force hit miss stale]
    def status(cache_key)
      payload_or_status = read0(cache_key, peek: true)
      return payload_or_status if payload_or_status.is_a?(Symbol)

      payload_or_status.error_999? ? :error : :hit
    end

    # Write response to the disk cache
    def write(cache_key, payload)
      path = diskpath(cache_key)
      FileUtils.mkdir_p(File.dirname(path))
      Zlib::GzipWriter.open(path) { payload.write(_1) }
    end

    # Relative path for this cache_key based on the cache key
    def diskpath(cache_key)
      File.join(dir, cache_key.diskpath)
    end

    protected

    # low level read, returns payload or status
    def read0(cache_key, peek: false)
      path = diskpath(cache_key)

      return :miss if !File.exist?(path)
      return :stale if expired?(path)
      return :force if force?

      payload = Zlib::GzipReader.open(path) { Payload.read(_1, peek: peek) }
      return :force if force_errors? && payload.error_999?

      payload
    end

    # Is this path expired?
    def expired?(path)
      expires_in && File.stat(path).mtime < Time.now - expires_in
    end
  end
end
