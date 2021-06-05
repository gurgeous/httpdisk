require_relative 'test_helper'

class TestSlopDuration < MiniTest::Test
  def test_duration
    option = Slop::DurationOption.new(nil, nil)

    # valid
    {
      '1': 1,
      '1s': 1,
      '1m': 60,
      '1h': (60 * 60),
      '1d': (24 * 60 * 60),
      '1w': (7 * 24 * 60 * 60),
      '1y': (365 * 7 * 24 * 60 * 60),
    }.each do
      assert_equal _2, option.call(_1.to_s)
    end

    # invalid
    ['', '1z', 'gub'].each do |s|
      assert_raises(Slop::Error) { option.call(s) }
    end
  end
end
