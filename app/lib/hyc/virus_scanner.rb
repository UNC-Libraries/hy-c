# switching from clamav gem to clamby gem
module Hyc
  class VirusScanner < Hydra::Works::VirusScanner
    def infected?
      Clamby.virus?(file)
    end
  end
end
