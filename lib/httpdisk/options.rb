module HTTPDisk
  # Like Slop, but for sanity checking method options. Useful for top level
  # library methods.
  class Options
    attr_reader :flags

    def self.parse(options, &block)
      Options.new(&block).parse(options)
    end

    #
    # flag methods
    #

    {
      array: Array,
      boolean: :boolean,
      custom: nil,
      float: Float,
      hash: Hash,
      integer: Integer,
      string: String,
      symbol: Symbol,
    }.each do |method, valid|
      define_method(method) do |flag, flag_options = {}|
        flags[flag] = { valid: valid }.merge(flag_options)
      end
    end

    #
    # return parsed options
    #

    def parse(options)
      # defaults
      options = defaults.merge(options.compact)

      # check
      flags.each do |flag, flag_options|
        value = options[flag]
        next if value.nil?

        valid = Array(flag_options[:valid])
        raise ArgumentError, error_message(flag, value, valid) if !valid?(value, valid)
      end

      # return
      options
    end

    protected

    def initialize
      @flags = {}
      yield(self)
    end

    def defaults
      flags.transform_values { |flag_options| flag_options[:default] }.compact
    end

    # does value match valid?
    def valid?(value, valid)
      valid.any? do
        case _1
        when nil then true if value.nil?
        when :boolean then true if [nil, true, false].include?(value)
        when Class then true if value.is_a?(_1)
        else
          # this thing is designed to raise ArgumentErrors, so raise something
          # else for this kind of snafu
          raise "unknown flag type #{_1.inspect}"
        end
      end
    end

    # nice error message for when value is invalid
    def error_message(flag, value, valid)
      message = valid.compact.map do
        s = _1.to_s
        s = s.downcase if s =~ /\b(Array|Float|Hash|Integer|String|Symbol)\b/
        s
      end.join('/')
      "expected :#{flag} to be #{message}, not #{value.inspect}"
    end
  end
end
