require 'rails_helper'
require 'fileutils'
require 'tmpdir'
require 'securerandom'

RSpec.describe RegisterToLongleafJob, type: :job do
  
  let(:md_dir) { Dir.mktmpdir('metadata') }
  let(:file_path) do
    file = Tempfile.new('ingest_me')
    # Generate a 6kb file so that fedora won't put it in the database
    six_kb = 6 * 1024
    File.write(file.path, SecureRandom.random_bytes( six_kb ).force_encoding('UTF-8'))
    file.path
  end
  let(:repository_file) do
    Hydra::PCDM::File.new.tap do |f|
      f.content = File.open(file_path).read
      f.original_name = "ingest_me"
      f.save!
    end
  end
  let(:job) { RegisterToLongleafJob.new }
  
  
  after do
    File.delete(file_path)
    FileUtils.rmdir(md_dir)
  end
  
  # Without longleaf configured
  context 'Without longleaf configured' do
    before(:each) do
      ENV.delete("LONGLEAF_BASE_COMMAND")
      ENV.delete("LONGLEAF_CONFIG")
      ENV.delete("LONGLEAF_LOG")
    end
    
    it 'logs notification' do
      job.perform(repository_file)
      
      # Verify that metadata dir is empty, meaning nothing was registered
      expect(Dir.empty?(md_dir)).to be true
    end
  end
  
  context 'With minimal config' do
    let(:binary_dir) { File.join(Rails.root, "tmp/fcrepo4-test-data/fcrepo.binary.directory/") }
    
    let(:config_path) do
      file = Tempfile.new('config')
      File.write(file.path,
          "locations:\n" +
          "  test_loc:\n" +
          "    path: #{binary_dir}\n" +
          "    metadata_path: #{md_dir}\n" +
          "services: {}\n" +
          "service_mappings: {}\n")
      file.path
    end
    
    before(:each) do
      ENV["FEDORA_BINARY_STORAGE"] = binary_dir
      ENV["LONGLEAF_BASE_COMMAND"] = 'longleaf %{cmd}'
      ENV["LONGLEAF_CONFIG"] = config_path
      ENV["LONGLEAF_LOG"] = '&1'
    end
    
    after do
      FileUtils.rmdir(binary_dir)
    end
    
    it 'registers file' do
      job.perform(repository_file)
      
      # Verify that the metadata directory is no longer empty, meaning a file was registered to it
      expect(Dir.empty?(md_dir)).to be false
    end
  end
end