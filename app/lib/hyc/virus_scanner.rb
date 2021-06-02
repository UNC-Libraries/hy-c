# switching from clamav gem to clamby gem to clamav-client gem
module Hyc
  class VirusScanner < Hydra::Works::VirusScanner
    def infected?
      client = ClamAV::Client.new
      results = client.execute(ClamAV::Commands::ScanCommand.new(file))
      results[0]
    end
  end
end
