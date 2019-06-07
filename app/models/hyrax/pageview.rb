module Hyrax
  class Pageview
    extend ::Legato::Model

    metrics :pageviews
    dimensions :date
    filter :for_path, &->(path) { contains(:pagePath, redirect(path)) }

    private

      def redirect(path)
        if ENV.has_key?('REDIRECT_FILE_PATH') && File.exist?(ENV['REDIRECT_FILE_PATH'])
          redirect_uuids = File.read(ENV['REDIRECT_FILE_PATH'])
        else
          redirect_uuids = File.read(Rails.root.join('lib', 'redirects', 'redirect_uuids.csv'))
        end

        csv = CSV.parse(redirect_uuids, headers: true)
        redirect_path = csv.find { |row| row['new_path'].match(path) }

        if redirect_path
          "#{path}|/record/uuid:#{redirect_path['uuid']}"
        else
          path
        end
      end
  end
end
