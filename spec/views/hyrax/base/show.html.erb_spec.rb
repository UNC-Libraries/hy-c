# frozen_string_literal: true
# [hyc-override] schema org information is shown in script tag
require 'rails_helper'

RSpec.describe 'hyrax/base/show.html.erb', type: :view do
  let(:user) { FactoryBot.create(:user) }
  let(:object_profile) { ["{'id':'999'}"] }
  let(:solr_document) do
    SolrDocument.new(
      id: '999',
      object_profile_ssm: object_profile,
      has_model_ssim: ['FileSet'],
      human_readable_type_tesim: ['File'],
      contributor_display_tesim: ['index:1||Kelce, Travis||Affiliation: Bowles Center for Alcohol Studies||ORCID: http://example.org'],
      creator_display_tesim: ['index:1||Swift, Taylor||Other Affiliation: Heartbreak University'],
      license_tesim: ['http://creativecommons.org/licenses/by/3.0/us/'],
      abstract_tesim: ['pop music'],
      title_tesim: ['Best Title'],
      subject_tesim: ['This album was created with love'],
      keyword_tesim: %w[pop country],
      language_tesim: ['English'],
      publisher_tesim: ['UNC Publishing']
    )
  end
  let(:ability) { Ability.new(user) }
  let(:presenter) do
    Hyrax::WorkShowPresenter.new(solr_document, ability)
  end
  let(:request) { double(host: 'example.org', base_url: 'http://example.org') }
  let(:workflow_presenter) do
    double('workflow_presenter', badge: 'Foobar')
  end
  let(:page) { Capybara::Node::Simple.new(rendered) }

  before do
    allow(controller).to receive(:current_ability).and_return(ability)
    allow(controller).to receive(:request).and_return(request)
    allow(controller).to receive(:controller_name).and_return('file_sets')
    allow(presenter).to receive(:editor?).and_return(true)
    allow(view).to receive(:workflow_restriction?).and_return(false)
    allow(view).to receive(:user_signed_in?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:polymorphic_url).and_return('polymorphic_url')
    allow(workflow_presenter).to receive(:is_mfa_in_review?).and_return(false)
    allow(workflow_presenter).to receive(:in_workflow_state?).and_return(false)

    stub_template 'hyrax/base/_citations.html.erb' => ''
    stub_template 'hyrax/base/_currently_shared.html.erb' => ''
    stub_template 'hyrax/base/_file_manager_thumbnail.html.erb' => ''
    stub_template 'hyrax/base/_items.html.erb' => ''
    stub_template 'hyrax/base/_metadata.html.erb' => ''
    stub_template 'hyrax/base/_relationships.html.erb' => ''
    stub_template 'hyrax/base/_show_actions.html.erb' => ''
    stub_template 'hyrax/base/_social_media.html.erb' => ''
    stub_template 'hyrax/base/_workflow_actions_widget.html.erb' => ''
    stub_template '_masthead.html.erb' => ''
    stub_template '_controls.html.erb' => ''
    stub_template 'layouts/_head_tag_content.html.erb' => ''
    stub_template 'shared/_footer.html.erb' => ''

    assign(:presenter, presenter)
    render template: 'hyrax/base/show', layout: 'layouts/hyrax/1_column'
  end

  it 'shows schema org script tag' do
    schema = {
      '@context' => 'https://schema.org',
      'name' => 'Best Title',
      'description' => 'pop music',
      'creator' => [{ '@type' => 'Person', 'name' => 'Swift, Taylor', 'affiliation' => 'Heartbreak University' }],
      'contributor' => [{ '@type' => 'Person',
                         'name' => 'Kelce, Travis',
                         'sameAs' => 'http://example.org',
                         'affiliation' => 'School of Medicine, Bowles Center for Alcohol Studies'}],
      'about' => [{ '@type' => 'Thing', 'name' =>'This album was created with love' }],
      'keywords' => %w[pop country],
      'license' => 'http://creativecommons.org/licenses/by/3.0/us/',
      'inLanguage' => [{ '@type' => 'Language', 'name' => 'English' }],
      'publisher' => [{ '@type' => 'Organization', 'name' => 'UNC Publishing' }],
      '@id' => 'polymorphic_url',
    }.compact

    expect(page).to have_content(schema.to_json)
  end
end
