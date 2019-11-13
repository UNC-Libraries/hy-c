require "rails_helper"
require "rake"

describe "rake onescience:ingest", type: :task do
  let(:admin_user) do
    User.find_by_user_key('admin')
  end

  let(:time) do
    Time.now
  end

  let(:admin_set) do
    AdminSet.create!(title: ["onescience default"],
                     description: ["some description"])
  end

  let(:permission_template) do
    Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
  end

  let(:workflow) do
    Sipity::Workflow.create!(name: 'test', allows_access_grant: true, active: true,
                             permission_template_id: permission_template.id)
  end

  before do
    AdminSet.delete_all
    Hyrax::PermissionTemplateAccess.delete_all
    Hyrax::PermissionTemplate.delete_all
    Hyrax::PermissionTemplateAccess.create!(permission_template: permission_template,
                                            agent_type: 'user',
                                            agent_id: admin_user.user_key,
                                            access: 'deposit')
    Sipity::WorkflowAction.create(name: 'show', workflow_id: workflow.id)
    Hyrax::Application.load_tasks if Rake::Task.tasks.empty?
  end

  it "preloads the Rails environment" do
    expect(Rake::Task['onescience:ingest'].prerequisites).to include "environment"
  end

  describe "running the ingest script" do
    after do
      File.delete('spec/fixtures/onescience/1science_completed.log')
      File.delete('spec/fixtures/onescience/1science_deposit_record_id.log')
    end

    it "creates a new work" do
      expect { Rake::Task['onescience:ingest'].invoke('spec/fixtures/onescience/onescience_config.yml', 'RAILS_ENV=test') }
          .to change{ Article.count }.by(1)
      new_article = Article.all[-1]
      expect(new_article['depositor']).to eq 'admin'
      expect(new_article['title']).to match_array ['A Multi-Institutional Longitudinal Faculty Development Program in Humanism Supports the Professional Development of Faculty Teachers']
      expect(new_article['label']).to eq 'A Multi-Institutional Longitudinal Faculty Development Program in Humanism Supports the Professional Development of Faculty Teachers'
      expect(new_article['date_issued']).to eq '2017'
      creators = new_article['creators'].map{|creator| creator['name'].inspect }.flatten
      expect(["Osterberg, Lars G.", "Frankel, Richard M.", "Branch, William T.", "Gilligan, MaryAnn C.",
              "Plews-Ogan, Margaret", "Dunne, Dana", "Hafler, Janet P.", "Litzelman, Debra K.", "Rider, Elizabeth A.",
              "Weil, Amy B.", "Derse, Arthur R.", "May, Natalie B."]).to include (new_article['creators'][0]['name'].first)
      expect(new_article['resource_type']).to match_array ['Article']
      expect(new_article['abstract']).to match_array ['The authors describe the first 11 academic years (2005–2006 through 2016–2017) of a longitudinal, small-group faculty development program for strengthening humanistic teaching and role modeling at 30 U.S. and Canadian medical schools that continues today. During the yearlong program, small groups of participating faculty met twice monthly with a local facilitator for exercises in humanistic teaching, role modeling, and related topics that combined narrative reflection with skills training using experiential learning techniques. The program focused on the professional development of its participants. Thirty schools participated; 993 faculty, including some residents, completed the program.']
      expect(new_article['dcmi_type']).to match_array ['http://purl.org/dc/dcmitype/Text']
      expect(new_article['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
      expect(new_article['deposit_record']).not_to be_nil
    end
  end
end
