require_relative "test_helper"

class TestClient < Minitest::Test
  CAFE = "café".encode("ISO-8859-1")

  def setup
    super

    @faraday = Faraday.new do
      _1.use :httpdisk, dir: @tmpdir
    end
  end

  def test_get
    r1, r2 = (1..2).map { @faraday.get "http://httpbingo" }
    assert !r1.env[:httpdisk]
    assert r2.env[:httpdisk]
    assert_equal 200, r1.status
    assert_requested(:get, "http://httpbingo", times: 1)
    assert_responses_equal r1, r2
  end

  def test_post_string
    r1, r2 = (1..2).map { @faraday.post("http://httpbingo", "somebody") }
    assert_requested(:post, "http://httpbingo", times: 1)
    assert_responses_equal r1, r2
  end

  def test_post_form
    r1, r2 = (1..2).map do
      @faraday.post("http://httpbingo") do
        _1.headers["Content-Type"] = "application/x-www-form-urlencoded"
        _1.body = URI.encode_www_form({b: 1, a: 2, c: 3})
      end
    end
    assert_requested(:post, "http://httpbingo", times: 1)
    assert_responses_equal r1, r2
  end

  def test_content_type
    # Content-Type: nil
    r1, r2 = (1..2).map { @faraday.get "http://httpbingo" }
    [r1, r2].each do
      assert_equal Encoding::ASCII_8BIT, _1.body.encoding
    end

    # Content-Type: bogus (shouldn't crash)
    stub_request(:get, "bogus").to_return(
      headers: {"Content-Type" => "text/html; charset=bogus"}
    )
    r1, r2 = (1..2).map { @faraday.get "http://bogus" }
    [r1, r2].each do
      assert_equal Encoding::ASCII_8BIT, _1.body.encoding
    end

    # Content-Type: ISO-8859-1
    stub_request(:get, "cafe").to_return(
      headers: {"Content-Type" => "text/html; charset=iso-8859-1"},
      body: CAFE
    )
    r1, r2 = (1..2).map { @faraday.get "http://cafe" }
    [r1, r2].each do
      assert_equal Encoding::ISO_8859_1, _1.body.encoding
      assert_equal CAFE, _1.body
    end

    # Content-Type: text/xml (ascii)
    stub_request(:get, "nocharset").to_return(
      headers: {"Content-Type" => "text/xml"}
    )
    r1, r2 = (1..2).map { @faraday.get "http://nocharset" }
    [r1, r2].each do
      assert_equal Encoding::ASCII_8BIT, _1.body.encoding
    end
  end

  def test_content_type_option_utf8
    faraday = Faraday.new do
      _1.use :httpdisk, dir: @tmpdir, utf8: true
    end

    # Content-Type: nil (ascii)
    r1, r2 = (1..2).map { faraday.get "http://httpbingo" }
    [r1, r2].each do
      assert_equal Encoding::ASCII_8BIT, _1.body.encoding
    end

    # Content-Type: text/xml (ascii)
    stub_request(:get, "nocharset").to_return(
      headers: {"Content-Type" => "text/xml"}
    )
    r1, r2 = (1..2).map { @faraday.get "http://nocharset" }
    [r1, r2].each do
      assert_equal Encoding::ASCII_8BIT, _1.body.encoding
    end

    # Content-Type: image/png (ascii)
    stub_request(:get, "png").to_return(
      headers: {"Content-Type" => "image/png"},
      body: "png"
    )
    r1, r2 = (1..2).map { faraday.get "http://png" }
    [r1, r2].each do
      assert_equal Encoding::ASCII_8BIT, _1.body.encoding
    end

    # Content-Type: ISO-8859-1 (convert to utf8)
    stub_request(:get, "cafe").to_return(
      headers: {"Content-Type" => "text/html; charset=iso-8859-1"},
      body: CAFE
    )
    r1, r2 = (1..2).map { faraday.get "http://cafe" }
    [r1, r2].each do
      assert_equal Encoding::UTF_8, _1.body.encoding
      assert_equal "café", _1.body
    end

    # Content-Type: UTF-7 (can't convert to UTF-8)
    stub_request(:get, "utf7").to_return(
      headers: {"Content-Type" => "text/html; charset=UTF-7"},
      body: "hello".dup.force_encoding("UTF-7")
    )
    r1, r2 = (1..2).map { faraday.get("http://utf7") }
    [r1, r2].each do
      assert_match(/could not convert/, _1.body)
      assert_equal Encoding::UTF_8, _1.body.encoding
    end
  end

  # these are the most common errors
  def test_errors
    [Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EHOSTUNREACH,
      OpenSSL::SSL::SSLError,
      SocketError,
      Timeout::Error].each do |error|
      url = "http://raise_#{error.to_s.gsub(/:+/, "_").downcase}"
      stub_request(:any, url).to_raise(error)
      r1, r2 = (1..2).map { @faraday.get(url) }
      assert_equal HTTPDisk::ERROR_STATUS, r1.status
      assert_requested(:get, url, times: 1)
      assert_responses_equal r1, r2
    end
  end

  def test_option_force
    faraday = Faraday.new do
      _1.use :httpdisk, dir: @tmpdir, force: true
    end

    2.times { faraday.get("http://httpbingo") }
    assert_requested(:get, "http://httpbingo", times: 2)
  end

  def test_option_logger
    faraday = Faraday.new do
      _1.use :httpdisk, dir: @tmpdir, logger: true
    end

    assert_output("", /miss.*hit/m) { 2.times { faraday.get("http://httpbingo") } }
  end

  protected

  def assert_responses_equal(r1, r2)
    %i[body headers reason_phrase status].each do
      assert_equal r1.send(_1), r2.send(_1)
    end
  end
end
