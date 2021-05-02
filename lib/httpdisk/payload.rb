module HTTPDisk
  class Payload
    class << self
      def read(f)
        Payload.new.tap do |p|
          # comment
          p.comment = f.gets[/^# (.*)/, 1]

          # status line
          m = f.gets.match(/^HTTPDISK (\d+) (.*)$/)
          p.status, p.reason_phrase = m[1].to_i, m[2]

          # headers
          while (line = f.gets.chomp) && !line.empty?
            key, value = line.split(': ', 2)
            p.headers[key] = value
          end

          # body
          p.body = f.read
        end
      end

      def from_response(response)
        Payload.new.tap do
          _1.body = response.body
          _1.headers = response.headers
          _1.reason_phrase = response.reason_phrase
          _1.status = response.status
        end
      end
    end

    attr_accessor :body, :comment, :headers, :reason_phrase, :status

    def initialize
      @body = ''
      @comment = ''
      @headers = Faraday::Utils::Headers.new
    end

    def error_999?
      status == HTTPDisk::ERROR_STATUS
    end

    def write(f)
      # comment
      f.puts "# #{comment}"

      # status line
      f.puts "HTTPDISK #{status} #{reason_phrase}"

      # headers
      headers.each { f.puts("#{_1}: #{_2}") }
      f.puts

      # body
      f.write(body)
    end
  end
end
