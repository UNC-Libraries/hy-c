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
        if !File.exist?(@filename)
          FileUtils.touch(@filename)
        end
      end
    end
  end
end
