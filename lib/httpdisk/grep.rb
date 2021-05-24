# manually load dependencies here since this is loaded standalone by bin
require 'httpdisk/grep_printer'
require 'httpdisk/payload'
require 'httpdisk/version'
require 'slop'

#
# tests?
#

module HTTPDisk
  class Grep
    attr_reader :options, :output, :total_matches, :tty

    def initialize(options)
      @options = options
      @output = $stdout
      @total_matches = 0
    end

    # enumerate file paths one at a time
    def run
      paths.each do
        begin
          run_one(_1)
        rescue StandardError => e
          raise GrepError, "#{e.message[0, 70]} (#{_1})"
        end
      end
      exit 1 if total_matches == 0
    end

    def run_one(path)
      # read payload and prettyprint json if necessary
      payload = Zlib::GzipReader.open(path) { Payload.read(_1) }
      body = payload.body
      if payload.headers['Content-Type'] =~ /\bjson\b/
        body = JSON.pretty_generate(JSON.parse(body))
      end

      # collect all_matches
      all_matches = body.each_line.map do |line|
        [].tap do |matches|
          line.scan(pattern) { matches << Regexp.last_match }
        end
      end.reject(&:empty?)
      return if all_matches.empty?

      # now print
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

    # regex pattern from options
    def pattern
      @pattern ||= Regexp.new(options[:pattern], Regexp::IGNORECASE)
    end

    # printer for output
    def printer
      @printer ||= case
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
        o.boolean '-c', '--count', 'suppresses normal output and shows the number of matching lines'
        o.boolean '-h', '--head', 'show headers before each match'
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
