# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/uploaders/hyrax/uploaded_file_uploader.rb
# [hyc-override] Overriding CarrierWave methods to allow files to be moved, rather than copied multiple times
Hyrax::UploadedFileUploader.class_eval do
  def move_to_cache
    true
  end

  def move_to_store
    true
  end
end
