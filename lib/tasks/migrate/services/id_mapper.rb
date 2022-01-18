module Migrate
  module Services
    class IdMapper

      def initialize(filename, col_1_name, col_2_name)
        @filename = filename
        create_csv(col_1_name, col_2_name)
      end

      def add_row(key, value)
        CSV.open(@filename, 'a+') do |csv|
          csv << [key, value]
        end
      end

      def mappings
        CSV.read(@filename, { headers: true })
      end

      private

      def create_csv(col_1_name, col_2_name)
        unless File.exist?(@filename)
          @filename = File.new(@filename, 'w')
          CSV.open(@filename, 'a+') do |csv|
            csv << [col_1_name, col_2_name]
          end
        end
      end
    end
  end
end
