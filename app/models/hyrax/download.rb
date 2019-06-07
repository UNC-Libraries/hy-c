module Hyrax
  class Download
    extend ::Legato::Model

    metrics :totalEvents
    dimensions :eventCategory, :eventAction, :eventLabel, :date
    filter :for_file, &->(id) { matches(:eventLabel, redirect(id)) }

    private

      def redirect(id)
        if ENV.has_key?('REDIRECT_FILE_PATH') && File.exist?(ENV['REDIRECT_FILE_PATH'])
          redirect_uuids = File.read(ENV['REDIRECT_FILE_PATH'])
        else
          redirect_uuids = File.read(Rails.root.join('lib', 'redirects', 'redirect_uuids.csv'))
        end

        csv = CSV.parse(redirect_uuids, headers: true)
        redirect_path = csv.find { |row| row['new_path'].match(id) }

        if redirect_path
          "#{id}|#{redirect_path['uuid']}"
        else
          id
        end
      end
  end
end
