desc 'Create a csv that affiliations that do not map to solr and their associated object ids'
task list_affiliations: :environment do
  ListUnmappableAffiliationsJob.perform_later
end
