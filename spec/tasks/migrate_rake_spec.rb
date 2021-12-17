# no further tests will be added for this task unless it is needed again in the future
# This test is not currently passing consistently on the VM. It may be worthwhile to look at deprecating
# it and the code it tests, or making any code we do want to keep more permanent and thoroughly tested

require "rails_helper"
require "rake"

describe "rake migrate:works", type: :task do
  let(:user) do
    User.find_by_user_key('admin')
  end

  let(:manager_group) do
    Role.create(name: 'test manager group')
  end

  let(:admin_set) do
    AdminSet.create(title: ['default'],
                    description: ['some description'],
                    edit_users: [user.user_key])
  end

  let(:permission_template) do
    Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
  end

  let(:workflow) do
    Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                            permission_template_id: permission_template.id)
  end

  let(:output_dir) { Dir.mktmpdir }

  before do
    Hyrax::Application.load_tasks if Rake::Task.tasks.empty?
    AdminSet.delete_all
    Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                           agent_type: 'user',
                                           agent_id: user.user_key,
                                           access: 'deposit')
    Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                           agent_type: 'group',
                                           agent_id: manager_group.name,
                                           access: 'manage')
    Sipity::WorkflowAction.create(name: 'show', workflow_id: workflow.id)

    watauga_county = <<RDFXML.strip_heredoc
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
          <rdf:RDF xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:gn="http://www.geonames.org/ontology#" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">
          <gn:Feature rdf:about="http://sws.geonames.org/4497707/">
          <gn:name>Watauga</gn:name>
          </gn:Feature>
          </rdf:RDF>
RDFXML
    stub_request(:get, "http://sws.geonames.org/4497707/").
        to_return(status: 200, body: watauga_county, headers: {'Content-Type' => 'application/rdf+xml;charset=UTF-8'})

    stub_request(:any, "http://api.geonames.org/getJSON?geonameId=4497707&username=#{ENV['GEONAMES_USER']}").
        with(headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'User-Agent' => 'Ruby'
        }).to_return(status: 200, body: { asciiName: 'Watauga County',
                                          countryName: 'United States',
                                          adminName1: 'North Carolina' }.to_json,
                     headers: { 'Content-Type' => 'application/json' })
  end

  after do
    FileUtils.remove_entry_secure output_dir
  end

  it "preloads the Rails environment" do
    expect(Rake::Task['migrate:works'].prerequisites).to include "environment"
  end

  xit "creates a new work" do
    expect { Rake::Task['migrate:works'].invoke('collection1',
                                                'spec/fixtures/migration/migration_config.yml',
                                                output_dir.to_s,
                                                'RAILS_ENV=test')
    }    
        .to change{ Article.count }.by(1)
    new_article = Article.all[-1]
    expect(new_article['depositor']).to eq 'admin'
    expect(new_article['title']).to match_array ['Les Miserables']
    expect(new_article['label']).to eq 'Les Miserables'
    expect(new_article['date_modified']).to eq 'Mon, 02 Oct 2017 17:46:28 +0000'
    expect(new_article['publisher']).to match_array ['Project Gutenberg']
    expect(new_article['language']).to match_array ['http://id.loc.gov/vocabulary/iso639-2/eng']
    expect(new_article['language_label']).to match_array ['English']
    expect(new_article['license']).to match_array ['http://creativecommons.org/licenses/by/3.0/us/']
    expect(new_article['license_label']).to match_array ['Attribution 3.0 United States']
    expect(new_article['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
    expect(new_article['rights_statement_label']).to eq 'In Copyright'
    expect(new_article['admin_set_id']).to eq admin_set.id
    expect(new_article['creators'][0]['index'].first).to eq 1
    expect(new_article.visibility).to eq 'restricted'
    expect(new_article.file_sets.count).to eq 2
  end
end
