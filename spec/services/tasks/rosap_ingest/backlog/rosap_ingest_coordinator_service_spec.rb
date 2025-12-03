# frozen_string_literal: true
RSpec.describe Tasks::ROSAPIngest::Backlog::ROSAPIngestCoordinatorService do
    let(:admin_set) { FactoryBot.build(:admin_set, title: ['ROSAP Ingest Admin Set']) }
    let(:config) do
        {
            'start_time' => DateTime.new(2024, 1, 1),
            'restart_time' => nil,
            'resume' => false,
            'admin_set_title' => admin_set.title,
            'depositor_onyen' => 'testuser',
            'output_dir' => '/tmp/rosap_ingest_output',
            'full_text_dir' => '/tmp/rosap_full_text'
        }
    end
    let(:tracker_hash) do
        {
            'depositor_onyen' => 'testuser',
            'progress' => {
                'metadata_ingest' => { 'completed' => false },
                'attach_files_to_works' => { 'completed' => false },
                'send_summary_email' => { 'completed' => false }
            }
        }.with_indifferent_access
    end
    let(:tracker) do
        double('Tracker', save: true).tap do |t|
            allow(t) to receive(:[]) { |key| tracker_hash[key] }
            allow(t) to receive(:[]=) { |key, value| tracker_hash[key] = value }
            # Mocking nested dig method
            allow(t) to receive(:dig) do |*keys|
               result = tracker_hash
               keys.each { |k| result = result[k] if result}
               result
            end
        end
    end    
    