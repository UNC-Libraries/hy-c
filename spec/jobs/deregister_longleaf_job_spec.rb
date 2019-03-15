require 'rails_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe DeregisterLongleafJob, type: :job do
  
  let(:admin_user) do
    User.find_by_user_key('admin@example.com')
  end
  
  let(:binary_dir) { File.join(Rails.root, "tmp/fcrepo4-test-data/fcrepo.binary.directory/") }
  
  let(:ll_home_dir) { Dir.mktmpdir('ll_home') }
  
  let(:repository_file) do
    Hydra::PCDM::File.new do |f|
      f.content = File.open(File.join(fixture_path, "hyrax/hyrax_test4.pdf"))
      f.original_name = 'test.pdf'
      f.mime_type = 'application/pdf'
    end
  end
  
  let(:file_set) { FileSet.new }
  
  let(:job) { DeregisterLongleafJob.new }
  
  after do
    FileUtils.rm_rf([ll_home_dir, binary_dir])
  end
  
  context 'With minimal config' do
    let(:output_path) { File.join(ll_home_dir, "output.txt")}
    
    let(:longleaf_script) do
      path = File.join(ll_home_dir, "llcommand.sh")
      File.write(path, "#!/usr/bin/env bash\n" +
          "echo $@ > #{output_path.to_s}")
      path
    end
    
    before do
      FileUtils.chmod("u+x", longleaf_script)
      ENV["LONGLEAF_STORAGE_PATH"] = binary_dir
      ENV["LONGLEAF_BASE_COMMAND"] = longleaf_script
      
      file_set.apply_depositor_metadata admin_user.user_key
      file_set.save!
      file_set.original_file = repository_file
      file_set.save!
    end
    
    after do
      ENV.delete("LONGLEAF_STORAGE_PATH")
      ENV.delete("LONGLEAF_BASE_COMMAND")
    end
    
    it 'calls deregistration script with the expected parameters' do
      job.perform(file_set)
      
      arguments = File.read(output_path)
      
      binary_path = File.join(binary_dir, "12/e5/f2/12e5f2da18960dc085ca27bec1ae9e3245389cb1")
      
      expect(arguments).to match(Regexp.new(".*deregister -f #{binary_path}"))
    end
  end
end