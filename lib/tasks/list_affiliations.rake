desc 'Create a csv that affiliations that do not map to solr and their associated object ids'
task list_affiliations: :environment do
  ListUnmappableAffiliationsJob.perform_later
end

desc 'Remediate affiliations that were previously found'
task remediate_affiliations: :environment do
  RemediateAffiliations.perform_later
end
