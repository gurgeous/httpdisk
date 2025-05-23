require_relative "test_helper"

# utf8 issue?

class TestGrep < Minitest::Test
  def setup
    super

    cache = HTTPDisk::Cache.new(dir: @tmpdir, expires: 60)

    # fruits & veggies
    fruits = %w[apple apricot avocado banana].join("\n")
    veggies = %w[artichoke asparagus beans].join("\n")
    cache.write(ck("http://f"), payload(body: fruits, headers: {fruits: "yum"}))
    cache.write(ck("http://v"), payload(body: veggies, headers: {veggies: "yum"}))

    ENV["GREP_COLOR"] = "37;45"
  end

  def test_bin_blackbox
    # --help (fast)
    output = `bin/httpdisk-grep --help`
    assert $CHILD_STATUS.success?
    assert_match("pattern", output)

    # search (slow)
    output = `bin/httpdisk-grep apple #{@tmpdir}`
    assert $CHILD_STATUS.success?
    assert_match("apple", output)
  end

  def test_basic
    # found, not found
    assert_output(/apple.*apricot.*avocado.*.*artichoke.*asparagus/m) { grep("^a").run }
    assert_output("") { grep("beef").run }

    # success return value
    assert grep("--silent ^a").run
    assert !grep("--silent beef").run

    # --count
    assert_output(/:3.*:2/m) { grep("--count ^a").run }
    # --head
    assert_output(/Fruits.*yum/m) { grep("--head apple").run }
    # --silent
    assert_output("") { grep("apple --silent").run }
  end

  def test_color
    # plain text
    assert_output(/avocado/) { grep("[vd]o").run }

    # under the hood $stdout becomes a StringIO inside assert_output
    StringIO.any_instance.stubs(:tty?).returns(true)
    assert_output(/37;45mvo.*37;45mdo/) { grep("[vd]o").run }
  end

  def test_body_processing
    grep = HTTPDisk::Grep::Main.new(nil)

    # honor charset
    payload = OpenStruct.new.tap do
      _1.body = "body"
      _1.headers = {"Content-Type" => "text/html; charset=ISO-8859-1"}
    end
    assert_equal "ISO-8859-1", grep.prepare_body(payload).encoding.name

    # pretty print json
    payload = OpenStruct.new.tap do
      _1.body = {a: 1}.to_json
      _1.headers = {"Content-Type" => "application/json; charset=utf-8"}
    end
    assert_equal "{\n  \"a\": 1\n}", grep.prepare_body(payload)
  end

  def test_non_gzip
    IO.write(File.join(@tmpdir, "bad"), "")
    assert_output(/not in gzip/) { grep("xyz").run }
  end

  protected

  def grep(args)
    args = args.split if args.is_a?(String)
    args << @tmpdir
    HTTPDisk::Grep::Main.new(HTTPDisk::Grep::Args.slop(args))
  end
end
