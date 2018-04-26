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
    new_article = Article.all[-1]
    expect(new_article['depositor']).to eq 'admin@example.com'
    expect(new_article['title']).to match_array ['Les Miserables']
    expect(new_article['label']).to eq 'Les Miserables'
    expect(new_article['date_created']).to match_array ['2017-10-02']
    expect(new_article['date_modified']).to eq '2017-10-02'
    expect(new_article['creator']).to match_array ['Hugo, Victor']
    expect(new_article['contributor']).to match_array ['Hugo, Victor']
    expect(new_article['publisher']).to match_array ['Project Gutenberg']
  end
end
