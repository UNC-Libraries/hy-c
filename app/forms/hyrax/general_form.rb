# Generated via
#  `rails generate hyrax:work General`
module Hyrax
  class GeneralForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::General

    self.terms += [:resource_type, :bibliographic_citation, :abstract, :academic_concentration, :access, :advisor,
                   :affiliation, :affiliation_label, :alternative_title, :arranger, :award, :composer, :conference_name,
                   :copyright_date, :date_captured, :date_issued, :date_other, :dcmi_type, :degree,
                   :degree_granting_institution, :deposit_record, :doi, :edition, :extent, :funder, :geographic_subject,
                   :graduation_year, :isbn, :issn, :journal_issue, :journal_title, :journal_volume, :kind_of_data,
                   :last_modified_date, :medium, :note, :orcid, :other_affiliation, :page_start, :page_end,
                   :peer_review_status, :place_of_publication, :project_director, :publisher_version, :researcher,
                   :reviewer, :rights_holder, :series, :sponsor, :table_of_contents, :translator, :url, :use]

    self.required_fields = [:title]

    self.terms -= [:based_near, :source]

    self.single_value_fields = [:title, :license, :rights_statement]
    
    self.admin_only_terms = [:dcmi_type]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def license
      super.first || ""
    end

    def rights_statement
      super.first || ""
    end


    # Select the correct affiliation type for committee member
    def affiliation_type(value)
      value = Array(value).first
      if value.blank? || value == 'UNC'
        affiliation_options[0]
      else
        affiliation_options[1]
      end
    end

    def affiliation_options
      ["UNC Advisor", "Non-UNC Advisor"]
    end

    # In the view we have "fields_for :advisors".
    # This method is needed to make fields_for behave as an
    # association and populate the form with the correct
    # committee member data.
    delegate :advisors_attributes=, to: :model

    # We need to call '.to_a' on advisors to force it
    # to resolve.  Otherwise in the form, the fields don't
    # display the committee member's name and affiliation.
    # Instead they display something like:
    # '#<ActiveTriples::Relation:0x007fb564969c88>'
    def advisors
      model.advisors.build if model.advisors.blank?
      model.advisors.to_a
    end

    def no_advisors
      str_advisors = model.advisors.to_a.join(',')
      value = str_advisors.count("a-zA-Z").zero?
      empty_advisors = value
      model.persisted? && empty_advisors
    end

    def self.build_permitted_params
      permitted = super
      permitted << { advisors_attributes: [:id, { name: [] }, { affiliation: [] }, :affiliation_type, { netid: [] }, :_destroy] }
      permitted
    end

    # If the student selects 'Emory Committee Chair' or
    # 'Emory Committee Member' for the 'affiliation_type' field,
    # then the 'affiliation' field becomes disabled in the form.
    # In that case, we need to fill in the 'affiliation' data
    # with 'Emory University', and we need to remove the
    # 'affiliation_type' field because that is not a valid field
    # for the CommitteeMember model.
    def self.model_attributes(form_params)
      attrs = super
      keys = ['advisors_attributes']

      keys.each do |field_name|
        next if attrs[field_name].blank?
        attrs[field_name].each do |member_key, member_attrs|
          aff_type = attrs[field_name][member_key].delete 'affiliation_type'

          names = attrs[field_name][member_key]['name'] || []
          netids = attrs[field_name][member_key]['netid'] || []
          names_blank = names.all?(&:blank?)
          netids_blank = netids.all?(&:blank?)
          next if names_blank && netids_blank

          if member_attrs['affliation'].blank? && aff_type && aff_type.start_with?('UNC')
            attrs[field_name][member_key]['affiliation'] = ['UNC']
          end
        end
      end

      attrs
    end
  end
end
