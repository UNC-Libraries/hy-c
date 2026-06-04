# frozen_string_literal: true

module Tasks
  module PubmedIngest
    module SharedUtilities
      module PmcS3VersionLookup
        PMC_S3_BUCKET = 'pmc-oa-opendata'
        PMC_S3_BASE_URL = "https://#{PMC_S3_BUCKET}.s3.amazonaws.com"

        def latest_version_prefix(pmcid)
          url = "#{PMC_S3_BASE_URL}/?list-type=2&prefix=#{pmcid}.&delimiter=/"
          response = HTTParty.get(url, timeout: 10)
          raise "S3 listing failed: #{response.code}" unless response.code == 200

          doc = Nokogiri::XML(response.body)
          doc.remove_namespaces!
          prefixes = doc.xpath('//CommonPrefixes/Prefix').map(&:text)
          return nil if prefixes.empty?

          prefixes.sort.last
        end
      end
    end
  end
end
