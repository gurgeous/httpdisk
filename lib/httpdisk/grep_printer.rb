module HTTPDisk
  class GrepPrinter
    attr_reader :output

    def initialize(output)
      @output = output
    end

    def print(path, payload, all_matches)
      raise NotImplementedError
    end

    protected

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

  # path:count
  class CountPrinter < GrepPrinter
    def print(path, _payload, all_matches)
      output.puts "#{path}:#{all_matches.length}"
    end
  end

  # header, then matches
  class HeaderPrinter < GrepPrinter
    attr_reader :head, :printed

    def initialize(output, head)
      super(output)
      @head = head
      @printed = 0
    end

    def print(path, payload, all_matches)
      # separator & filename
      output.puts if (@printed += 1) > 1
      output.puts path

      # --head
      if head
        io = StringIO.new
        payload.write_header(io)
        io.string.lines.each { output.puts "< #{_1}" }
      end

      # matches
      all_matches.each { print_matches(_1) }
    end
  end

  # path:match
  class TersePrinter < GrepPrinter
    def print(path, _payload, all_matches)
      all_matches.each do
        output.write("#{path}:")
        print_matches(_1)
      end
    end
  end
end
