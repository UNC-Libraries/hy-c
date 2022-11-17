# frozen_string_literal: true
# add method to make files private and change the owner to the admin group
module Hyrax
  module Workflow
    module MetadataOnlyRecord
      def self.call(user:, target:, **)
        target.file_ids.each do |file_id|
          file_set = FileSet.find(file_id)
          Hyrax::Actors::FileSetActor.new(file_set, user)
                                     .update_metadata(visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
        end
      end
    end
  end
end
