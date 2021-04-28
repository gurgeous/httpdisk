require_relative 'test_helper'

class TestClient < MiniTest::Test
  def setup
    super

    @faraday = Faraday.new do
      _1.use :httpdisk, dir: @tmpdir
    end
  end

  def test_get
    r1, r2 = (1..2).map { @faraday.get 'http://httpbingo' }
    assert !r1.env[:httpdisk]
    assert r2.env[:httpdisk]
    assert_equal 200, r1.status
    assert_requested(:get, 'http://httpbingo', times: 1)
    assert_responses_equal r1, r2
  end

  def test_post_string
    r1, r2 = (1..2).map { @faraday.post('http://httpbingo', 'somebody') }
    assert_requested(:post, 'http://httpbingo', times: 1)
    assert_responses_equal r1, r2
  end

  def test_post_form
    r1, r2 = (1..2).map do
      @faraday.post('http://httpbingo') do
        _1.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        _1.body = URI.encode_www_form({ b: 1, a: 2, c: 3 })
      end
    end
    assert_requested(:post, 'http://httpbingo', times: 1)
    assert_responses_equal r1, r2
  end

  # these are the most common errors
  def test_errors
    [ Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EHOSTUNREACH,
      OpenSSL::SSL::SSLError,
      SocketError,
      Timeout::Error, ].each do |error|
      url = "http://raise_#{error.to_s.gsub(/:+/, '_').downcase}"
      stub_request(:any, url).to_raise(error)
      r1, r2 = (1..2).map { @faraday.get(url) }
      assert_equal HTTPDisk::ERROR_STATUS, r1.status
      assert_requested(:get, url, times: 1)
      assert_responses_equal r1, r2
    end
  end

  def test_force
    faraday = Faraday.new do
      _1.use :httpdisk, dir: @tmpdir, force: true
    end

    2.times { faraday.get('http://httpbingo') }
    assert_requested(:get, 'http://httpbingo', times: 2)
  end

  protected

  def assert_responses_equal(r1, r2)
    %i[body headers reason_phrase status].each do
      assert_equal r1.send(_1), r2.send(_1)
    end
  end
end
