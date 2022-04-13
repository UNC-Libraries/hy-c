require 'rails_helper'

RSpec.describe VersionService do
  it 'can return the git sha' do
    expect(described_class.git_sha).to be
  end

  it 'can return the branch name' do
    expect(described_class.branch_name).to be
  end

  it 'can return the tag name' do
    expect(described_class.tag_name).to be
  end

  it 'can return the directory name' do
    expect(described_class.directory_name).to be
  end

  context 'on a branch' do
    before do
      allow(described_class).to receive(:branch_name).and_return('my-cool-branch')
    end
    it 'returns a branch name' do
      expect(described_class.branch).to eq('my-cool-branch')
    end
  end

  context 'on a tag' do
    before do
      allow(described_class).to receive(:branch_name).and_return('HEAD')
      allow(described_class).to receive(:tag_name).and_return('my-cool-tag')
    end
    it 'returns a branch name' do
      expect(described_class.branch).to eq('my-cool-tag')
    end
  end

  context 'in a deployed environment' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(described_class).to receive(:directory_name).and_return('/path/to/releases/20211202095413')
    end

    it 'can give a deploy date' do
      expect(described_class.deploy_date).to eq('20211202095413')
    end

    it 'can give a phrase about the deploy date' do
      expect(described_class.deploy_date_phrase).to eq('Deployed on December 2, 2021')
    end
    context 'with an unexpected directory name' do
      before do
        allow(described_class).to receive(:directory_name).and_return('/path/to/releases/cheeseburger')
      end

      it 'can give a phrase about the deploy date' do
        expect(described_class.deploy_date_phrase).to eq('Cannot determine deploy date')
      end
    end
  end

  context 'in a development environment' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      allow(described_class).to receive(:directory_name).and_return('/hyrax')
    end

    it 'can give a phrase about the deploy date' do
      expect(described_class.deploy_date_phrase).to eq('Not in deployed environment')
    end
  end
end
