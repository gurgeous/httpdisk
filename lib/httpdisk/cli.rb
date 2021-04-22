require 'faraday-cookie_jar'
require 'faraday_middleware'
require 'ostruct'

module HTTPDisk
  # Command line httpdisk command.
  class Cli
    attr_reader :options

    # for --expires
    UNITS = {
      s: 1,
      m: 60,
      h: 60 * 60,
      d: 24 * 60 * 60,
      w: 7 * 24 * 60 * 60,
      y: 365 * 7 * 24 * 60 * 60,
    }.freeze

    def initialize(options)
      @options = options
    end

    # we have a very liberal retry policy
    RETRY_OPTIONS = {
      methods: %w[delete get head options patch post put trace],
      retry_statuses: (400..600).to_a,
      retry_if: ->(_env, _err) { true },
    }.freeze

    # Make the request (or print status)
    def run
      # short circuit --status
      if options[:status]
        status
        return
      end

      # create Faraday client
      faraday = create_faraday

      # run request
      response = faraday.run_request(request_method, request_url, request_body, request_headers)
      if response.status >= 400
        raise CliError, "the requested URL returned error: #{response.status} #{response.reason_phrase}"
      end

      # output
      if options[:output]
        File.open(options[:output], 'w') { output(response, _1) }
      else
        output(response, $stdout)
      end
    end

    def create_faraday
      Faraday.new do
        # connection settings
        _1.proxy = proxy if options[:proxy]
        _1.options.timeout = options[:max_time] if options[:max_time]

        # cookie middleware
        _1.use :cookie_jar

        # BEFORE httpdisk so each redirect segment is cached
        _1.response :follow_redirects

        # httpdisk
        _1.use :httpdisk, client_options

        # AFTER httpdisk so transient failures are not cached
        if options[:retry]
          _1.request :retry, RETRY_OPTIONS.merge(max: options[:retry])
        end
      end
    end

    # Support for --status
    def status
      # build env
      env = Faraday::Env.new.tap do
        _1.method = request_method
        _1.request_body = request_body
        _1.request_headers = request_headers
        _1.url = request_url
      end

      # now print status
      client = HTTPDisk::Client.new(nil, client_options)
      client.status(env).each do
        puts "#{_1}: #{_2.inspect}"
      end
    end

    # Output response to f
    def output(response, f)
      if options[:include]
        f.puts "HTTPDISK #{response.status} #{response.reason_phrase}"
        response.headers.each { f.puts("#{_1}: #{_2}") }
        f.puts
      end
      f.write(response.body)
    end

    #
    # request_XXX
    #

    # HTTP method (get, post, etc.)
    def request_method
      method = if options[:request]
        options[:request]
      elsif options[:data]
        'post'
      end
      method ||= 'get'
      method = method.downcase.to_sym

      if !Faraday::Connection::METHODS.include?(method)
        raise CliError, "invalid --request #{method.inspect}"
      end
      method
    end

    # Request url
    def request_url
      url = options[:url]
      # recover from missing http:
      if url !~ %r{^https?://}i
        if url =~ %r{^\w+://}
          raise CliError, 'only http/https supported'
        end
        url = "http://#{url}"
      end
      URI.parse(url)
    rescue URI::InvalidURIError
      raise CliError, "invalid url #{url.inspect}"
    end

    # Request body
    def request_body
      options[:data]
    end

    # Request headers
    def request_headers
      {}.tap do |headers|
        if options[:user_agent]
          headers['User-Agent'] = options[:user_agent]
        end

        options[:header].each do |header|
          key, value = header.split(': ', 2)
          if !key || !value || key.empty? || value.empty?
            raise CliError, "invalid --header #{header.inspect}"
          end
          headers[key] = value
        end
      end
    end

    #
    # helpers
    #

    # Options to HTTPDisk::Client
    def client_options
      {}.tap do |client_options|
        client_options[:dir] = options[:dir]
        if options[:expires]
          seconds = parse_expires(options[:expires])
          if !seconds
            raise CliError, "invalid --expires #{options[:expires].inspect}"
          end
          client_options[:expires_in] = seconds
        end
        client_options[:force] = options[:force]
        client_options[:force_errors] = options[:force_errors]
      end
    end

    # Return validated --proxy flag if present
    def proxy
      return if !options[:proxy]

      proxy = parse_proxy(options[:proxy])
      raise CliError, "--proxy should be host[:port], not #{options[:proxy].inspect}" if !proxy
      proxy
    end

    # Parse --expires flag
    def parse_expires(s)
      m = s.match(/^(\d+)([smhdwy])?$/)
      return if !m

      num, unit = m[1].to_i, (m[2] || 's').to_sym
      return if !UNITS.key?(unit)

      num * UNITS[unit]
    end

    # Parse --proxy flag
    def parse_proxy(proxy_flag)
      host, port = proxy_flag.split(':', 2)
      return if !host || host.empty?
      return if port&.empty?

      URI.parse('http://placeholder').tap do
        begin
          _1.host = host
          _1.port = port if port
        rescue URI::InvalidComponentError
          return
        end
      end.to_s
    end
  end
end
