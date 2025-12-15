# frozen_string_literal: true
module Tasks::StacksIngest::Backlog::Utilities::AttributeBuilders
  class StacksAttributeBuilder < Tasks::IngestHelperUtils::SharedAttributeBuilders::OaiPmhAttributeBuilder
    private
    def set_identifiers(article)
      identifiers = []
      if metadata['cdc_id'].present?
        identifiers << "Stacks-CDC ID: #{metadata['cdc_id']}"
      end
      article.identifier = identifiers
    end
  end
end
