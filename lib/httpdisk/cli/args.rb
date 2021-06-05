# manually load dependencies here since this is loaded standalone by bin
require 'httpdisk/error'
require 'httpdisk/slop_duration'
require 'httpdisk/version'
require 'slop'

module HTTPDisk
  module Cli
    # Slop parsing. This is broken out so we can run without require 'httpdisk'.
    module Args
      def self.slop(args)
        slop = Slop.parse(args) do |o|
          o.banner = 'httpdisk [options] [url]'

          # similar to curl
          o.separator 'Similar to curl:'
          o.string '-d', '--data', 'HTTP POST data'
          o.array '-H', '--header', 'pass custom header(s) to server', delimiter: nil
          o.boolean '-i', '--include', 'include response headers in the output'
          o.integer '-m', '--max-time', 'maximum time allowed for the transfer'
          o.string '-o', '--output', 'write to file instead of stdout'
          o.string '-x', '--proxy', 'use host[:port] as proxy'
          o.string '-X', '--request', 'HTTP method to use'
          o.integer '--retry', 'retry request if problems occur'
          o.boolean '-s', '--silent', "silent mode (don't print errors)"
          o.string '-A', '--user-agent', 'send User-Agent to server'

          # from httpdisk
          o.separator 'Specific to httpdisk:'
          o.string '--dir', 'httpdisk cache directory (defaults to ~/httpdisk)'
          o.duration '--expires', 'when to expire cached requests (ex: 1h, 2d, 3w)'
          o.boolean '--force', "don't read anything from cache (but still write)"
          o.boolean '--force-errors', "don't read errors from cache (but still write)"
          o.boolean '--status', 'show status for a url in the cache'

          # generic
          o.boolean '--version', 'show version' do
            puts "httpdisk #{HTTPDisk::VERSION}"
            exit
          end
          o.on '--help', 'show this help' do
            puts o
            exit
          end
        end

        raise Slop::Error, '' if args.empty?
        raise Slop::Error, 'no URL specified' if slop.args.empty?
        raise Slop::Error, 'more than one URL specified' if slop.args.length > 1

        slop.to_h.tap do
          _1[:url] = slop.args.first
        end
      end
    end
  end
end
