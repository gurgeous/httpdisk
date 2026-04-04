require_relative "test_helper"

class TestCacheKey < Minitest::Test
  def test_key
    # happy path
    assert_equal "GET http://example.com", ck("http://example.com").key
    assert_equal "GET http://example.com:123", ck("http://example.com:123").key

    # these should match
    [
      %w[http://a?a=1&b=2&c=3 http://A:80?c=3&b=2&a=1],
      %w[https://a?a=1&b=2&c=3 https://A:443?c=3&b=2&a=1],
      %w[https://a? https://A:443/],
      %w[http://a?b+c=d+e http://a?b%20c=d%20e]
    ].each do
      assert_equal ck(_1).key, ck(_2).key
    end

    # methods should differ
    refute_equal ck("http://a").key, ck("http://a", method: "post").key

    # bodies should differ
    refute_equal ck("http://a").key, ck("http://a", body: "hi").key

    # should assert
    [
      "",
      "file://localhost/fileurl",
      "https:///nohost"
    ].each do
      assert_raises { ck(_1).key }
    end
  end

  def test_bodykey
    # form
    request_headers = {"Content-Type" => "application/x-www-form-urlencoded"}
    body = URI.encode_www_form({b: 1, a: 2, c: 3})
    ck = ck("http://gub", body:, request_headers:)
    assert_equal "a=2&b=1&c=3", ck.send(:bodykey)
    # w/ ignore_params
    ck = ck("http://gub", body:, request_headers:, ignore_params: %w[b])
    assert_equal "a=2&c=3", ck.send(:bodykey)

    # short string
    ck = ck("http://gub", body: "hello")
    assert_equal "hello", ck.send(:bodykey)

    # long string
    ck = ck("http://gub", body: "hello" * 99)
    assert_equal "01922dc3fd1270b9478bb280236b6a1a", ck.send(:bodykey)
  end

  def test_hostdir
    # happy path
    assert_equal "example.com", ck("http://www.Example.com").send(:hostdir)

    # edge cases
    assert_equal "hithere", ck("http://hi~there").send(:hostdir)
    assert_equal "hi.there", ck("https://hi...there").send(:hostdir)
    assert_equal "any", ck("http://~~").send(:hostdir)
  end

  def test_digest
    # path should contain hostdir & digest
    ck = ck("http://www.google.com")
    assert_match "google.com", ck.diskpath
    assert_match ck.digest, ck.diskpath.delete("/")
  end

  def test_ignore_params
    %w[
      http://example.com?b=2&a=1&c=3
      http://example.com?a=1&c=3
      http://example.com?a=1&c=3&b=hi
    ].each do
      assert_equal "GET http://example.com?a=1&c=3", ck(_1, ignore_params: %w[b]).key
    end
  end

  def test_mutation
    cache_key = ck("https://api.github.com/repos/me/project/commits?per_page=100&since=2024-01-01")
    cache_key.query_params = cache_key.query_params.merge("since" => "last_90_days")
    cache_key.path = "/repos/me/project/commits/last_90_days"

    assert_equal "GET https://api.github.com/repos/me/project/commits/last_90_days?per_page=100&since=last_90_days", cache_key.key
  end

  def test_mutation_updates_digest_and_diskpath
    cache_key = ck("http://example.com?a=1")
    digest = cache_key.digest
    diskpath = cache_key.diskpath

    cache_key.query = "a=2"

    refute_equal digest, cache_key.digest
    refute_equal diskpath, cache_key.diskpath
  end
end
