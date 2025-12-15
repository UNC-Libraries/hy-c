# frozen_string_literal: true
module Tasks::StacksIngest::Backlog::Utilities
  class StacksMetadataResolver < Tasks::IngestHelperUtils::OaiPmhMetadataResolver

    def construct_attribute_builder
      Tasks::StacksIngest::Backlog::Utilities::AttributeBuilders::StacksAttributeBuilder.new(@resolved_metadata, @admin_set, @depositor_onyen)
    end
  end
end
