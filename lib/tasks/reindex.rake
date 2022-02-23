namespace 'hyc' do
  desc 'Reindexes to Solr - Hy-C flavor'
  task reindex: :environment do
    # NOTE: In order to see progress in the logs, you must have logging at :info or above
    ReindexJob.perform_later
  end
end
