require_relative 'test_helper'

class TestOptions < MiniTest::Test
  def test_invalid
    skip

    # good
    [
      [{}, {}],
      [{ a: nil }, { a: [nil] }],
      [{ a: nil }, { a: :boolean }],
      [{ a: true }, { a: [:boolean] }],
      [{ a: false }, { a: [:boolean] }],
      [{ a: 'gub' }, { a: [String] }],
      [{ a: Logger.new($stdout) }, { a: [:boolean, Logger] }],
      [{ a: 123 }, { a: [Integer] }],
    ].each do |options, schema|
      HTTPDisk::Sanity.new(options, schema).check!
    end

    # bad
    [
      [{ a: nil }, { a: [String] }],
      [{ a: 34 }, { a: [String] }],
      [{ a: 12 }, { a: [:boolean] }],
      [{ a: '12' }, { a: [Integer] }],
    ].each do |options, schema|
      assert_raises(ArgumentError) { HTTPDisk::Sanity.new(options, schema).check! }
    end
  end
end
