require 'set'

module Migrate
  module Services
    class ProgressTracker

      def initialize(filename)
        @filename = filename
        create_log
      end

      def add_entry(entry)
        File.open(@filename, 'a+') do |file|
          file.puts(entry)
        end
      end

      def completed_set
        IO.readlines(@filename).map { |entry| entry.chomp }.to_set
      end

      private

      def create_log
        FileUtils.touch(@filename) if !File.exist?(@filename)
      end
    end
  end
end
