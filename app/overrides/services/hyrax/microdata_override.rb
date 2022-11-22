# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/services/hyrax/microdata.rb
Hyrax::Microdata.class_eval do
  # [hyc-override] Check for local schema.org file, so our overrides can take effect.
  def self.load_paths
    local_schema_file = Rails.root.join('config', 'schema_org.yml')
    local_filename = File.file?(local_schema_file) ? local_schema_file : FILENAME
    @load_paths ||= [local_filename]
  end
end
