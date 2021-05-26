# manually load dependencies here since this is loaded standalone by bin
require 'httpdisk/grep_printer'
require 'httpdisk/payload'
require 'httpdisk/version'
require 'find'
require 'json'
require 'slop'

#
# tests?
#

module HTTPDisk
  class Grep
    attr_reader :options, :success, :tty

    def initialize(options)
      @options = options
    end

    # Enumerate file paths one at a time. Returns true if matches were found.
    def run
      paths.each do
        begin
          run_one(_1)
        rescue StandardError => e
          if ENV['HTTPDISK_DEBUG']
            $stderr.puts
            $stderr.puts e.class
            $stderr.puts e.backtrace.join("\n")
          end
          raise GrepError, "#{e.message[0, 70]} (#{_1})"
        end
      end
      success
    end

    def run_one(path)
      # read payload & body
      payload = Zlib::GzipReader.open(path) { Payload.read(_1) }
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
      roots = ['.'] if roots.empty?

      # find files in roots
      paths = roots.flat_map { Find.find(_1).to_a }.sort
      paths = paths.select { File.file?(_1) }

      # strip default './'
      paths = paths.map { _1.gsub(%r{^\./}, '') } if options[:roots].empty?
      paths
    end

    # convert raw body into something palatable for pattern matching
    def prepare_body(payload)
      body = payload.body

      if content_type = payload.headers['Content-Type']
        # Mismatches between Content-Type and body.encoding are fatal, so make
        # an effort to align them.
        if charset = content_type[/charset=([^;]+)/, 1]
          encoding = begin
            Encoding.find(charset)
          rescue StandardError
            nil
          end
          if encoding && body.encoding != encoding
            body.force_encoding(encoding)
          end
        end

        # pretty print json for easier searching
        if content_type =~ /\bjson\b/
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
      @printer ||= case
      when options[:quiet]
        QuietPrinter.new
      when options[:count]
        CountPrinter.new($stdout)
      when options[:head] || $stdout.tty?
        HeaderPrinter.new($stdout, options[:head])
      else
        TersePrinter.new($stdout)
      end
    end

    # Slop parsing. This is broken out so we can run without require 'httpdisk'.
    def self.slop(args)
      slop = Slop.parse(args) do |o|
        o.banner = 'httpdisk-grep [options] pattern [path ...]'
        o.boolean '-c', '--count', 'suppress normal output and show count'
        o.boolean '-h', '--head', 'show req headers before each match'
        o.boolean '-q', '--quiet', 'do not print anything to stdout'
        o.boolean '--version', 'show version' do
          puts "httpdisk-grep #{HTTPDisk::VERSION}"
          exit
        end
        o.on '--help', 'show this help' do
          puts o
          exit
        end
      end

      raise Slop::Error, '' if args.empty?
      raise Slop::Error, 'no PATTERN specified' if slop.args.empty?

      slop.to_h.tap do
        _1[:pattern] = slop.args.shift
        _1[:roots] = slop.args
      end
    end
  end
end
