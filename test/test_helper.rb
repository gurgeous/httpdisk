require 'English'
require 'httpdisk'
require 'minitest/autorun'
require 'mocha/minitest'
require 'webmock/minitest'

module MiniTest
  class Test
    def setup
      @tmpdir = Dir.mktmpdir('httpdisk')
      @httpbingo_stub = stub_request(:any, /httpbingo/).to_return { httpbingo(_1) }
    end

    def teardown
      FileUtils.rm_rf(@tmpdir)
      WebMock.reset!
    end

    protected

    # helper for creating a cache_key
    def ck(url, method: 'get', request_headers: {}, body: nil, ignore_params: [])
      env = Faraday::Env.new.tap do
        _1.body = body
        _1.request_headers = request_headers
        _1.method = method
        _1.url = Faraday.new.build_url(url)
      end
      HTTPDisk::CacheKey.new(env, ignore_params: ignore_params)
    end

    # helper for creating a payload
    def payload(body: nil, comment: nil, reason_phrase: nil, status: nil, headers: {})
      HTTPDisk::Payload.new.tap do
        _1.body = body || 'somebody'
        _1.comment = comment || 'hi there'
        _1.headers.update(headers)
        _1.reason_phrase = reason_phrase || 'OK'
        _1.status = status || 200
      end
    end

    #
    # a really bad httpbingo.org for webmock
    #

    def httpbingo(request)
      # support for /redirect/:n
      case request.uri.path
      when %r{/redirect/(\d+)}
        n = Regexp.last_match(1).to_i
        location = n > 1 ? "/redirect/#{n - 1}" : '/get'
        return { status: 302, headers: { Location: location } }
      end

      # otherwise just echo
      body = {}.tap do |h|
        if q = request.uri.query
          h[:args] = CGI.parse(q).map { [_1, _2.join(',')] }.to_h
        end
        h[:body] = request.body
        h[:headers] = request.headers
        h[:method] = request.method
        h[:rand] = rand # helpful for testing caching
      end.compact

      { body: JSON.pretty_generate(body) }
    end
  end
end
