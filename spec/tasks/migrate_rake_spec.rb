require "rails_helper"
require "rake"

describe "rake cdr:migration:items", type: :task do

  before { Hyrax::Application.load_tasks if Rake::Task.tasks.empty? }

  it "preloads the Rails environment" do
    expect(Rake::Task['cdr:migration:items'].prerequisites).to include "environment"
  end

  it "creates a new work" do
    expect { Rake::Task['cdr:migration:items'].invoke('spec/fixtures/migration', 'Article', 'RAILS_ENV=test') }
        .to change{ Article.count }.by(1)
    expect(Article.last['depositor']).to eq 'admin@example.com'
    expect(Article.last['title']).to match_array ['Les Miserables']
    expect(Article.last['label']).to eq 'Les Miserables'
    expect(Article.last['date_created']).to match_array ['2017-10-02']
    expect(Article.last['date_modified']).to eq '2017-10-02'
    expect(Article.last['creator']).to match_array ['Hugo, Victor']
    expect(Article.last['contributor']).to match_array ['Hugo, Victor']
    expect(Article.last['publisher']).to match_array ['Project Gutenberg']
  end
end
