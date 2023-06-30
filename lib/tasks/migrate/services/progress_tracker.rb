# frozen_string_literal: true
require 'set'

module Migrate
  module Services
    class ProgressTracker

      def initialize(filename)
        @filename = filename
        @write_mutex = Mutex.new
        create_log
      end

      def add_entry(entry)
        # Prevent multiple threads from writing to the file at the same time
        @write_mutex.synchronize do
          File.open(@filename, 'a+') do |file|
            file.puts(entry)
          end
        end
      end

      def completed_set
        IO.readlines(@filename).map { |entry| entry.chomp }.to_set
      end

      private

      def create_log
        FileUtils.touch(@filename) unless File.exist?(@filename)
      end
    end
  end
end
