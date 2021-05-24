module HTTPDisk
  class GrepPrinter
    attr_reader :output

    def initialize(output)
      @output = output
    end

    def print(path, payload, all_matches)
      print_start(path, payload, all_matches)
      all_matches.each { print_line(path, payload, _1) }
      print_end(path, payload, all_matches)
    end

    protected

    #
    # override these
    #

    def print_start(path, payload, all_matches); end

    def print_line(path, payload, matches); end

    def print_end(path, payload, all_matches); end

    #
    # helpers
    #

    def grep_color
      @grep_color ||= (ENV['GREP_COLOR'] || '37;45')
    end

    def print_matches(matches)
      s = matches.first.string
      if output.tty?
        s = [].tap do |result|
          ii = 0
          matches.each do
            result << s[ii..._1.begin(0)]
            result << "\e[#{grep_color}m#{_1[0]}\e[0m"
            ii = _1.end(0)
          end
          result << s[ii..]
        end.join
      end
      output.puts s
    end
  end

  #
  # subclasses
  #

  # prints path:count
  class CountPrinter < GrepPrinter
    def print_end(path, _payload, all_matches)
      output.puts "#{path}:#{all_matches.length}"
    end
  end

  # prints a header, then each match
  class HeaderPrinter < GrepPrinter
    attr_reader :head, :printed

    def initialize(output, head)
      super(output)
      @head, @printed = head, 0
    end

    def print_start(path, payload, _all_matches)
      # separator & filename
      output.puts if (@printed += 1) > 1
      output.puts path
      return if !head

      # head
      io = StringIO.new
      payload.write_header(io)
      io.string.lines.each { output.puts "< #{_1}" }
    end

    def print_line(_path, _payload, matches)
      print_matches(matches)
    end
  end

  # prints each match as path:match
  class TersePrinter < GrepPrinter
    def print_line(path, _payload, matches)
      output.write("#{path}:")
      print_matches(matches)
    end
  end
end
