# Generated via
#  `rails generate hyrax:work Multimedia`
module Hyrax
  class MultimediaForm < Hyrax::Forms::WorkForm
    self.model_class = ::Multimedia
    self.terms += [:abstract, :extent, :genre, :geographic_subject, :note, :resource_type]

    self.terms -= [:admin_set_id, :based_near, :bibliographic_citation, :contributor, :description,
                   :embargo_release_date, :files, :identifier, :import_url, :in_works_ids, :label,
                   :lease_expiration_date, :member_of_collection_ids, :ordered_member_ids, :source, :publisher,
                   :related_url, :relative_path, :rendering_ids, :representative_id, :thumbnail_id,
                   :visibility, :visibility_after_embargo, :visibility_after_lease, :visibility_during_embargo,
                   :visibility_during_lease
    ]

    self.required_fields -= [:keyword, :rights_statement]

    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end
  end
end
