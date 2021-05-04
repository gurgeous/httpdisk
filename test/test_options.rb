require_relative 'test_helper'

class TestOptions < MiniTest::Test
  def test_empty
    HTTPDisk::Options.parse({}) { _1.string :x }
  end

  def test_types
    options = HTTPDisk::Options.new do
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
      { array: [1] },
      { bool: true },
      { boolean: false },
      { boolean: true },
      { float: 1.23 },
      { float: 456 },
      { hash: { a: 1 } },
      { integer: 4 },
      { string: 'hi' },
      { symbol: :x },
    ].each do |args|
      options.parse(args)
    end

    # invalid
    [
      { array: 'str' },
      { bool: 'str' },
      { boolean: 'str' },
      { float: 'str' },
      { hash: 'str' },
      { integer: 'str' },
      { string: :bogus },
      { symbol: 'str' },
    ].each do |args|
      assert_raises(ArgumentError) { options.parse(args) }
    end
  end

  def test_on
    options = HTTPDisk::Options.new do
      _1.on :x, type: [:boolean, :integer, Logger]
    end
    [true, 123, Logger.new(nil)].each do
      options.parse(x: _1)
    end
    assert_raises(ArgumentError) { options.parse(x: 'str') }
  end

  def test_defaults
    options = HTTPDisk::Options.new do
      _1.integer :x, default: 123
    end
    assert_equal 123, options.parse({})[:x]
    assert_equal 123, options.parse({ x: nil })[:x]
    assert_equal 456, options.parse({ x: 456 })[:x]
  end

  def test_required
    assert_raises(ArgumentError) do
      HTTPDisk::Options.parse({}) { _1.string :x, required: true }
    end
  end
end
