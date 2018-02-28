desc "Adds sample data for oai tests"
task :test_data_import => :environment do
  sample_data = YAML.load(File.read(File.expand_path('../../../spec/fixtures/oai_sample_documents.yml', __FILE__)))
  sample_data.each do |data|
    doc = data[1]
    work = Article.new
    work.creator = [doc['creator']]
    work.depositor = doc['depositor']
    work.label = doc['label']
    work.title = [doc['title']]
    work.date_created = doc['date_created']
    work.date_modified = doc['date_modified']
    work.contributor = [doc['contributor']]
    work.description = [doc['description']]
    work.related_url = [doc['related_url']]
    work.resource_type = [doc['resource_type']]
    work.language = [doc['language']]
    work.rights_statement = [doc['rights_statement']]
    work.visibility = doc['visibility']
    work.save
    sleep 1
  end
end