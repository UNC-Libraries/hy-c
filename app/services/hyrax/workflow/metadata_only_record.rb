# frozen_string_literal: true
# add method to make files private and change the owner to the admin group
module Hyrax
  module Workflow
    module MetadataOnlyRecord
      def self.call(user:, target:, **)
        work = Wings::ActiveFedoraConverter.convert(resource: target)
        work.file_sets.each do |file_set|
          # puts "File set #{file_set} #{file_set.class.name}"
          Hyrax::Actors::FileSetActor.new(file_set, user)
                                     .update_metadata(visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
        end
      end
    end
  end
end
