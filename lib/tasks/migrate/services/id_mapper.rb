module Migrate
  module Services
    class IdMapper

      def initialize(filename)
        @filename = filename
        create_csv
      end

      def add_row(data)
        CSV.open(@filename, 'a+') do |csv|
          csv << [data[0], data[1]]
        end
      end

      private

        def create_csv
          if !File.exist?(@filename)
            @filename = File.new(@filename, 'w')
            CSV.open(@filename, 'a+') do |csv|
              csv << ['old', 'new']
            end
          end
        end
    end
  end
end
