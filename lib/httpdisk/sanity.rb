module HTTPDisk
  # Internal helper class for sanity checking options. Schema should be a hash
  # from key to allowed value types. Use :boolean as a shortcut for true/false.
  class Sanity
    attr_reader :options, :schema

    def initialize(options, schema)
      @options, @schema = options, schema
    end

    # raise if not sane
    def check!
      schema.each do |key, valid|
        value = options[key]
        valid = Array(valid)
        raise ArgumentError, error_message(key, value, valid) if !valid?(value, valid)
      end
    end

    protected

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
          raise "unknown Sanity schema type #{_1.inspect}"
        end
      end
    end

    # nice error message for when value is invalid
    def error_message(key, value, valid)
      msg = valid.compact.map do
        s = _1.to_s
        s = s.downcase if s =~ /\b(Integer|String)\b/
        s
      end.join('/')
      "expected :#{key} to be #{msg}, not #{value.inspect}"
    end
  end
end
