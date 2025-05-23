require_relative "test_helper"

class TestOptions < Minitest::Test
  def test_empty
    HTTPDisk::Sloptions.parse({}) { _1.string :x }
  end

  def test_types
    options = HTTPDisk::Sloptions.new do
      _1.array :array
      _1.bool :bool
      _1.boolean :boolean
      _1.float :float
      _1.hash :hash
      _1.integer :integer
      _1.string :string
      _1.symbol :symbol
    end

    # valid
    [
      {array: [1]},
      {bool: true},
      {boolean: false},
      {boolean: true},
      {boolean: "anything"},
      {float: 1.23},
      {float: 456},
      {hash: {a: 1}},
      {integer: 4},
      {string: "hi"},
      {symbol: :x}
    ].each do |args|
      options.parse(args)
    end

    # invalid
    [
      {array: "str"},
      {float: "str"},
      {hash: "str"},
      {integer: "str"},
      {string: :bogus},
      {symbol: "str"}
    ].each do |args|
      assert_raises(ArgumentError) { options.parse(args) }
    end
  end

  def test_on
    options = HTTPDisk::Sloptions.new do
      _1.on :x, type: [:integer, Logger]
    end
    [123, Logger.new(nil)].each do
      options.parse(x: _1)
    end
    assert_raises(ArgumentError) { options.parse(x: "str") }
  end

  def test_boolean
    options = HTTPDisk::Sloptions.new do
      _1.boolean :x
    end
    assert_nil options.parse({})[:x]
    assert_equal false, options.parse({x: false})[:x]
    assert_equal true, options.parse({x: true})[:x]
    assert_equal true, options.parse({x: 456})[:x]
  end

  def test_defaults
    options = HTTPDisk::Sloptions.new do
      _1.integer :x, default: 123
    end
    assert_equal 123, options.parse({})[:x]
    assert_equal 123, options.parse({x: nil})[:x]
    assert_equal 456, options.parse({x: 456})[:x]
  end

  def test_required
    assert_raises(ArgumentError) do
      HTTPDisk::Sloptions.parse({}) { _1.string :x, required: true }
    end
  end
end
