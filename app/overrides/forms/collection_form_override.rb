# [hyc-override] Overriding to remove :based_near (location) from form. Gives error if populated
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
