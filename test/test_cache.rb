require_relative 'test_helper'

class TestCache < MiniTest::Test
  def setup
    super

    @cache = HTTPDisk::Cache.new(dir: @tmpdir, expires: 60)
  end

  def test_invalid
    # not found
    assert_nil @cache.read(ck('http://notfound'))

    # stale
    ck = ck('http://stale')
    path = @cache.diskpath(ck)
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.touch(path, mtime: Time.now - 999)
    assert_nil @cache.read(ck)
  end

  def test_roundtrip
    ck = ck('http://hello')

    # write
    write_payload = payload(headers: { HELLO: 'wor:ld', name: 'john' })
    @cache.write(ck, write_payload)

    # read
    read_payload = @cache.read(ck)

    # should be identical
    %i[body comment headers reason_phrase status].each do
      assert_equal write_payload.send(_1), read_payload.send(_1)
    end
  end

  def test_status
    seq = lambda do
      ck = ck('http://seq')
      [].tap do |results|
        # no file
        FileUtils.rm_f(@cache.diskpath(ck))
        results << @cache.status(ck)

        # fresh hit
        @cache.write(ck, payload)
        results << @cache.status(ck)

        # stale hit
        FileUtils.touch(@cache.diskpath(ck), mtime: Time.now - 999)
        results << @cache.status(ck)

        # fresh error
        @cache.write(ck, payload(status: 500))
        results << @cache.status(ck)

        # stale error
        FileUtils.touch(@cache.diskpath(ck), mtime: Time.now - 999)
        results << @cache.status(ck)
      end
    end

    # normal flow
    @cache = HTTPDisk::Cache.new(dir: @tmpdir, expires: 60)
    assert_equal %i[miss hit stale error stale], seq.call

    # force
    @cache = HTTPDisk::Cache.new(dir: @tmpdir, expires: 60, force: true)
    assert_equal %i[miss force stale force stale], seq.call

    # force_errors
    @cache = HTTPDisk::Cache.new(dir: @tmpdir, expires: 60, force_errors: true)
    assert_equal %i[miss hit stale force stale], seq.call
  end

  def test_delete
    ck = ck('http://hello')
    @cache.write(ck, payload(body: 'hi'))
    assert_equal :hit, @cache.status(ck)
    @cache.delete(ck)
    assert_equal :miss, @cache.status(ck)
  end

  def test_bad_header_encoding
    # response headers are supposed to be ascii, but that isn't always the case
    ck = ck('http://hello')

    # write
    cafe = 'café'.encode('ISO-8859-1')
    write_payload = payload(headers: { cafe: cafe })
    @cache.write(ck, write_payload)

    # read
    read_payload = @cache.read(ck)
    assert_equal cafe.b, read_payload.headers[:cafe]
  end
end
