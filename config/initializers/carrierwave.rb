# frozen_string_literal: true
CarrierWave.tmp_path = File.join(ENV.fetch('TEMP_STORAGE'), 'carrierwave_tmp')