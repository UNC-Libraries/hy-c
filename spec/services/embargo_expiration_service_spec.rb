require 'rails_helper'
include Warden::Test::Helpers

describe EmbargoExpirationService, :clean do
  context "rake task" do
    let(:expiration_service_instance) { instance_double(described_class) }
    it "sets the default date to today if no value is passed" do
      allow(described_class).to receive(:new).and_return(expiration_service_instance)
      allow(expiration_service_instance).to receive(:run)
      described_class.run(nil)
      expect(described_class).to have_received(:new).with(Time.zone.today)
    end
    it "sets the run date if passed" do
      allow(described_class).to receive(:new).and_return(expiration_service_instance)
      allow(expiration_service_instance).to receive(:run)
      described_class.run("2018-01-28")
      expect(described_class).to have_received(:new).with(Date.parse("2018-01-28"))
    end
  end

  context "date formatting" do
    let(:service) { described_class.new(Time.zone.tomorrow) }
    it "formats a date so it can be used in a solr query" do
      date = Date.parse('2017-07-27')
      expect(service.solrize_date(date)).to eq "2017-07-27T00:00:00Z"
    end
    it "formats single digit days correctly" do
      date = Date.parse('2017-08-04')
      expect(service.solrize_date(date)).to eq "2017-08-04T00:00:00Z"
    end
  end

  context "#expire_embargoes" do
    sample_data = YAML.load(File.read(File.expand_path('../../../spec/fixtures/embargo_expiration_service.yml', __FILE__)))

    doc = sample_data[1]
    work = Article.new
    work.creator = [doc['creator']]
    work.depositor = doc['depositor']
    work.label = doc['label']
    work.title = [doc['title']]
    work.date_created = doc['date_created']
    work.date_modified = doc['date_modified']
    work.contributor = [doc['contributor']]
    work.description = doc['description']
    work.related_url = [doc['related_url']]
    work.resource_type = [doc['resource_type']]
    work.language = [doc['language']]
    work.language_label = [doc['language_label']]
    work.rights_statement = doc['rights_statement']
    work.visibility = doc['visibility']
    work.visibility_after_embargo =  doc['visibility_after_embargo']
    work.embargo_release_date = Time.zone.tomorrow
    work.save!
    sleep 1

    let(:article) { work }
    let(:service) { described_class.new(Time.zone.tomorrow + 1.days) }

    it "removes the embargo for each object whose expiration date has been reached" do
      expect(article.embargo_release_date).to eq(Time.zone.tomorrow)
      expect(article.under_embargo?).to eq true
      service.expire_embargoes
      article.reload

      # Visibility during embargo was restricted and intended visibility after embargo was open"
      expect(article.under_embargo?).to eq false
    end

    it "changes the work's visibility" do
      expect { service.expire_embargoes }
          .to change { article.reload.visibility }
                  .from(article.visibility)
                  .to(article.visibility_after_embargo)
    end

    context "when the embargo is not expired" do
      let(:service) { described_class.new(Time.zone.now) }

      it 'does not deactivate embargo' do
        expect { service.expire_embargoes }
            .not_to change { article.visibility }
                        .from(article.visibility)

        expect(article.under_embargo?).to be_truthy
      end
    end
  end
end
