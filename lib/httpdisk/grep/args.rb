# manually load dependencies here since this is loaded standalone by bin
require "httpdisk/version"
require "slop"

module HTTPDisk
  module Grep
    module Args
      # Slop parsing. This is broken out so we can run without require 'httpdisk'.
      def self.slop(args)
        slop = Slop.parse(args) do |o|
          o.banner = "httpdisk-grep [options] pattern [path ...]"
          o.boolean "-c", "--count", "suppress normal output and show count"
          o.boolean "-h", "--head", "show req headers before each match"
          o.boolean "-s", "--silent", "do not print anything to stdout"
          o.boolean "--version", "show version" do
            puts "httpdisk-grep #{HTTPDisk::VERSION}"
            exit
          end
          o.on "--help", "show this help" do
            puts o
            exit
          end
        end

        raise Slop::Error, "" if args.empty?
        raise Slop::Error, "no PATTERN specified" if slop.args.empty?

        slop.to_h.tap do
          _1[:pattern] = slop.args.shift
          _1[:roots] = slop.args
        end
      end
    end
  end
end
