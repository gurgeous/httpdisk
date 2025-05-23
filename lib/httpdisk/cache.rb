require "fileutils"
require "tempfile"

module HTTPDisk
  # Disk cache for cache_keys => response. Files are compressed.
  class Cache
    attr_reader :options

    def initialize(options)
      @options = options
    end

    %i[dir expires force force_errors plain].each do |method|
      define_method(method) do
        options[method]
      end
    end
    alias_method :force?, :force
    alias_method :force_errors?, :force_errors
    alias_method :plain?, :plain

    # Get cached response. If there is a cached error it will be raised.
    def read(cache_key)
      payload_or_status = read0(cache_key)
      payload_or_status.is_a?(Symbol) ? nil : payload_or_status
    end

    # Cache status for a cache_key, %i[error force hit miss stale]
    def status(cache_key)
      payload_or_status = read0(cache_key, peek: true)
      return payload_or_status if payload_or_status.is_a?(Symbol)

      payload_or_status.error? ? :error : :hit
    end

    # Write response to the disk cache
    def write(cache_key, payload)
      path = diskpath(cache_key)
      FileUtils.mkdir_p(File.dirname(path))

      # Atomically write gzipped payload. Put our underlying Tempfile into
      # binmode to avoid accidental newline conversion or string encoding. Not
      # required for *nix systems, but I've heard rumors it's helpful for
      # Windows.
      Tempfile.new(binmode: true).tap do |tmp|
        if plain?
          payload.write(tmp)
        else
          Zlib::GzipWriter.new(tmp).tap do |gzip|
            payload.write(gzip)
            gzip.close
          end
        end
        tmp.close
        FileUtils.mv(tmp.path, path)
      end
    end

    # Delete existing response, if any
    def delete(cache_key)
      path = diskpath(cache_key)
      FileUtils.rm(path) if File.exist?(path)
    end

    # Relative path for this cache_key based on the cache key
    def diskpath(cache_key)
      File.join(dir, cache_key.diskpath)
    end

    protected

    GZIP_MAGIC_NUMBER = [0x1F, 0x8B, 0x08]

    # low level read, returns payload or status
    def read0(cache_key, peek: false)
      path = diskpath(cache_key)

      return :miss if !File.exist?(path)
      return :stale if expired?(path)
      return :force if force?

      begin
        payload = File.open(path, encoding: "ASCII-8BIT") do |file|
          # is it gzipped?
          if file.read(3).bytes.tap { file.rewind } == GZIP_MAGIC_NUMBER
            Zlib::GzipReader.wrap(file, encoding: "ASCII-8BIT") do |gz|
              Payload.read(gz, peek:)
            end
          else
            Payload.read(file, peek:)
          end
        end
      rescue => e
        raise "#{path}: #{e}"
      end
      return :force if force_errors? && payload.error?

      payload
    end

    # Is this path expired?
    def expired?(path)
      expires && File.stat(path).mtime < Time.now - expires
    end
  end
end
