# frozen_string_literal: true
# [hyc-override] Overriding to remove :based_near (location) from form. Gives error if populated
# https://github.com/samvera/hyrax/blob/v2.9.6/app/forms/hyrax/forms/collection_form.rb
Hyrax::Forms::CollectionForm.class_eval do
  self.terms -= [:based_near]

  def secondary_terms
    [:creator,
     :contributor,
     :keyword,
     :license,
     :publisher,
     :date_created,
     :subject,
     :language,
     :identifier,
     :related_url,
     :resource_type]
  end
end
