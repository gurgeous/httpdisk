require_relative "test_helper"

class TestCli < MiniTest::Test
  def setup
    super
    stub_request(:any, /silent/)
  end

  def test_bin_blackbox
    # --help (fast)
    output = `bin/httpdisk --help`
    assert $CHILD_STATUS.success?
    assert_match(/similar to curl/i, output)

    # --status (slow)
    output = `bin/httpdisk --status example.com`
    assert $CHILD_STATUS.success?
    assert_match("status:", output)
  end

  #
  # end-to-end tests
  #

  def test_basic
    2.times { cli("silent").run }
    assert_requested(:get, "silent", times: 1)
  end

  def test_500
    stub_request(:get, "error").to_return(status: 500)
    assert_raises(HTTPDisk::CliError) { cli("error").run }
  end

  def test_bad_options
    assert_raises(HTTPDisk::CliError) { cli("--header bad ignore.com").run }
    assert_raises(HTTPDisk::CliError) { cli("--request bad ignore.com").run }
    assert_raises(HTTPDisk::CliError) { cli("{}").run }
  end

  #
  # curl flags
  #

  def test_user_agent
    cli("--user-agent gub silent").run
    assert_requested :get, "silent", headers: {"User-Agent" => "gub"}
  end

  def test_header
    cli(["--header", "Gub: zub", "silent"]).run
    assert_requested :get, "silent", headers: {"Gub" => "zub"}
  end

  def test_data
    cli("--data gub=zub silent").run
    assert_requested :post, "silent", body: "gub=zub"
  end

  def test_include
    cli = cli("--include silent")
    assert_output(/HTTPDISK 200/) { cli.run }
  end

  def test_max_time
    skip if !ENV["TEST_NETWORK"]

    WebMock.allow_net_connect!
    remove_request_stub(@httpbingo_stub)
    cli = cli("--max-time 1 http://httpbingo.org/delay/10")
    assert_raises(HTTPDisk::CliError) { cli.run }
  end

  def test_request
    cli("--request patch silent").run
    assert_requested :patch, "silent"
  end

  def test_output
    tmp = "#{@tmpdir}/tmp"
    cli("--include --output #{tmp} silent").run
    assert_match(/HTTPDISK 200/, IO.read(tmp))
  end

  def test_proxy
    http = Net::HTTP.new("silent")
    Net::HTTP.stubs(:new).returns(http).with("silent", 80, "boom", 123, nil, nil)

    cli("--proxy boom:123 silent").run
    assert_requested(:get, "silent", times: 1)
  end

  def test_url
    assert_equal URI.parse("https://a.com"), HTTPDisk::Cli::Main.new(url: "https://a.com").request_url
    assert_equal URI.parse("http://a.com"), HTTPDisk::Cli::Main.new(url: "a.com").request_url

    # zero or >1 urls result in an error
    [[], ["a.com", "b.com"]].each do
      assert_raises { HTTPDisk::Cli::Main.slop(_1) }
    end
  end

  #
  # httpdisk flags
  #

  def test_dir
    cli = cli("--dir /gub silent")
    assert_equal "/gub", cli.client_options[:dir]
  end

  def test_expires
    cli = cli("--expires 1h silent")
    assert_equal 60 * 60, cli.client_options[:expires]
  end

  def test_force
    2.times { cli("--force silent").run }
    assert_requested(:get, "silent", times: 2)
  end

  def test_status
    cli = cli("--status silent")
    assert_output(/miss/) { cli.run }
  end

  protected

  def cli(args)
    args = args.split if args.is_a?(String)
    args += ["--dir", @tmpdir] if !args.include?("--dir")
    HTTPDisk::Cli::Main.new(HTTPDisk::Cli::Args.slop(args))
  end
end
