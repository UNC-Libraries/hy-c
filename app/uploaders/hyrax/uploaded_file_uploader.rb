# frozen_string_literal: true
# [hyc-override] Overriding to allow files to be moved, rather than copied multiple times
module Hyrax
  class UploadedFileUploader < CarrierWave::Uploader::Base
    # Override the directory where uploaded files will be stored.
    # This is a sensible default for uploaders that are meant to be mounted:
    def store_dir
      configured_upload_path + "#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
    end

    def cache_dir
      configured_cache_path + "#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
    end

    def move_to_cache
      true
    end

    def move_to_store
      true
    end

    private

    def configured_upload_path
      Hyrax.config.upload_path.call
    end

    def configured_cache_path
      Hyrax.config.cache_path.call
    end
  end
end
