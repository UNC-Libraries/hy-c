# Generated via
#  `rails generate hyrax:work DataSet`
class DataSet < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = DataSetIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  self.human_readable_type = 'Data Set'

  # This must be included at the end, because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata
end
