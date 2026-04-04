require "find"
require "json"

module HTTPDisk
  module Grep
    class Main
      attr_reader :options, :success

      def initialize(options)
        @options = options
      end

      # Enumerate file paths one at a time. Returns true if matches were found.
      def run
        paths.each do
          run_one(_1)
        rescue => e
          if ENV["HTTPDISK_DEBUG"]
            $stderr.puts
            warn e.class
            warn e.backtrace.join("\n")
          end
          raise CliError, "#{e.message[0, 70]} (#{_1})"
        end
        success
      end

      def run_one(path)
        # read payload & body
        begin
          payload = Zlib::GzipReader.open(path, encoding: "ASCII-8BIT") do
            Payload.read(_1)
          end
        rescue Zlib::GzipFile::Error
          puts "httpdisk: #{path} not in gzip format, skipping" if !options[:silent]
          return
        end

        body = prepare_body(payload)

        # collect all_matches
        all_matches = body.each_line.map do |line|
          [].tap do |matches|
            line.scan(pattern) { matches << Regexp.last_match }
          end
        end.reject(&:empty?)
        return if all_matches.empty?

        # print
        @success = true
        printer.print(path, payload, all_matches)
      end

      # file paths to be searched
      def paths
        # roots
        roots = options[:roots]
        roots = ["."] if roots.empty?

        # find files in roots
        paths = roots.flat_map { Find.find(_1).to_a }.sort
        paths = paths.select { File.file?(_1) }

        # strip default './'
        paths = paths.map { _1.gsub(%r{^\./}, "") } if options[:roots].empty?
        paths
      end

      # convert raw body into something palatable for pattern matching
      def prepare_body(payload)
        body = payload.body

        if (content_type = payload.headers["Content-Type"])
          # Mismatches between Content-Type and body.encoding are fatal, so make
          # an effort to align them.
          if (charset = content_type[/charset=([^;]+)/, 1])
            encoding = begin
              Encoding.find(charset)
            rescue
              nil
            end
            if encoding && body.encoding != encoding
              body = body.dup.force_encoding(encoding)
            end
          end

          # pretty print json for easier searching
          if /\bjson\b/.match?(content_type)
            body = JSON.pretty_generate(JSON.parse(body))
          end
        end

        body
      end

      # regex pattern from options
      def pattern
        @pattern ||= Regexp.new(options[:pattern], Regexp::IGNORECASE)
      end

      # printer for output
      def printer
        @printer ||= if options[:silent]
          Grep::SilentPrinter.new
        elsif options[:count]
          Grep::CountPrinter.new($stdout)
        elsif options[:head] || $stdout.tty?
          Grep::HeaderPrinter.new($stdout, options[:head])
        else
          Grep::TersePrinter.new($stdout)
        end
      end
    end
  end
end
