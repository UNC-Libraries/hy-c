# switching from clamav gem to clamby gem to clamav-client gem
module Hyc
  class VirusScanner < Hydra::Works::VirusScanner
    # Hyrax requires an infected? method and that this method return a boolean
    def infected?
      results = hyc_infected?
      return results if results.instance_of? ClamAV::ErrorResponse
      results.instance_of? ClamAV::VirusResponse
    end

    # Hyc custom method to return virus signature as well as virus status
    def hyc_infected?
      connection = ClamAV::Connection.new(socket: ::TCPSocket.new('localhost', '3310'), wrapper: ::ClamAV::Wrappers::NewLineWrapper.new)
      client = ClamAV::Client.new(connection)
      results = client.execute(ClamAV::Commands::ScanCommand.new(file))
      results[0]
    end

    def self.hyc_infected?(file_path)
      new(file_path).hyc_infected?
    end
  end
end
