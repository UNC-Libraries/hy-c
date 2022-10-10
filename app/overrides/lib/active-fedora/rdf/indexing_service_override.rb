# frozen_string_literal: true
# [hyc-override] Storing person display and label information in solr
# https://github.com/samvera/active_fedora/blob/v12.2.4/lib/active_fedora/rdf/indexing_service.rb

ActiveFedora::RDF::IndexingService.class_eval do
  # [hyc-override] fields in person class
  class_attribute :person_fields
  self.person_fields = %w[advisors arrangers composers contributors creators project_directors researchers reviewers translators]

  # @param [#resource, #rdf_subject] obj the object to build an solr document for. Its class must respond to 'properties'
  # @param [ActiveFedora::Indexing::Map] index_config the configuration to use to map object values to index document values
  def initialize(obj, index_config = nil)
    unless index_config
      Deprecation.warn(self, 'initializing ActiveFedora::RDF::IndexingService without an index_config is deprecated and will be removed in ActiveFedora 13.0')
      index_config = obj.class.index_config
    end
    @object = obj
    @index_config = index_config

    # [hyc-override] initialize label variables
    @person_label = []
    @creator_label = []
    @advisor_label = []
    @contributor_label = []
    @orcid_label = []
    @affiliation_label = []
    @other_affiliation_label = []
  end

  protected

  # [hyc-override] store display and label fields in solr
  # Built in based_near attributes requires full field info
  def add_assertions(prefix_method, solr_doc = {})
    fields.each do |field_key, field_info|
      if person_fields.include? field_key.to_s
        unless field_info.values.blank?
          field_to_use = field_key == 'based_near' ? field_info : field_info.behaviors
          append_to_solr_doc(solr_doc,
                             solr_document_field_name(("#{field_key.to_s[0...-1]}_display").to_sym, prefix_method),
                             field_to_use,
                             build_person_display(field_key, field_info.values))
        end
      else
        solr_field_key = solr_document_field_name(field_key, prefix_method)
        field_info.values.each do |val|
          field_to_use = solr_field_key == 'based_near' ? field_info : field_info.behaviors
          value = val

          if solr_field_key == 'date_created'
            value = if val.is_a? DateTime
                      Hyc::EdtfConvert.convert_from_edtf(val.strftime('%Y-%m-%d'))
                    else
                      Hyc::EdtfConvert.convert_from_edtf(val)
                    end
          end

          append_to_solr_doc(solr_doc, solr_field_key, field_to_use, value)
        end
      end
    end

    # Add label fields to solr_doc
    append_to_solr_doc(solr_doc,
                       solr_document_field_name(('person_label').to_sym, prefix_method),
                       [:stored_searchable],
                       @person_label.flatten)
    append_to_solr_doc(solr_doc,
                       solr_document_field_name(('orcid_label').to_sym, prefix_method),
                       [:stored_searchable],
                       @orcid_label.flatten)
    append_to_solr_doc(solr_doc,
                       solr_document_field_name(('affiliation_label').to_sym, prefix_method),
                       [:stored_searchable, :facetable],
                       @affiliation_label.flatten)
    append_to_solr_doc(solr_doc,
                       solr_document_field_name(('other_affiliation_label').to_sym, prefix_method),
                       [:stored_searchable],
                       @other_affiliation_label.flatten)
    append_to_solr_doc(solr_doc,
                       solr_document_field_name(('creator_label').to_sym, prefix_method),
                       [:stored_searchable, :facetable],
                       @creator_label.flatten)
    append_to_solr_doc(solr_doc,
                       solr_document_field_name(('advisor_label').to_sym, prefix_method),
                       [:stored_searchable, :facetable],
                       @advisor_label.flatten)
    append_to_solr_doc(solr_doc,
                       solr_document_field_name(('contributor_label').to_sym, prefix_method),
                       [:stored_searchable, :facetable],
                       @contributor_label.flatten)

    solr_doc
  end

  # [hyc-override] replaced field_info with behaviors in params
  def append_to_solr_doc(solr_doc, solr_field_key, behaviors, val)
    ActiveFedora::Indexing::Inserter.create_and_insert_terms(solr_field_key,
                                       solr_document_field_value(val),
                                       behaviors,
                                       solr_doc)
  end

  # [hyc-override] add method for serializing display data
  private

  def build_person_display(field_key, people)
    displays = []
    people.each do |person|
      display_text = []
      person_name = Array(person['name'])
      unless person_name.first.blank?
        display_text << "index:#{Array(person['index']).first}" if person['index']
        display_text << person_name.first
        @person_label.push(person_name)
        if field_key.to_s == 'creators'
          @creator_label.push(person_name)
        elsif field_key.to_s == 'advisors'
          @advisor_label.push(person_name)
        elsif field_key.to_s == 'contributors'
          @contributor_label.push(person_name)
        end

        orcid = Array(person['orcid'])
        display_text << "ORCID: #{orcid.first}" unless orcid.first.blank?
        @orcid_label.push(orcid)

        display_text = build_affiliations(person['affiliation'], display_text)

        other_affil = Array(person['other_affiliation'])
        display_text << "Other Affiliation: #{other_affil.first}" unless other_affil.first.blank?
        @other_affiliation_label.push(other_affil)

        displays << display_text.join('||')
      end
    end
    displays.flatten
  end

  def build_affiliations(affiliation_identifier, display_text)
    affiliations = split_affiliations(affiliation_identifier)
    unless affiliations.blank?
      display_text << "Affiliation: #{affiliations.join(', ')}"

      affiliation_ids = Array(affiliation_identifier)
      short_labels = affiliation_ids.map do |affil_id|
        DepartmentsService.short_label(affil_id)
      end
      @affiliation_label.push(short_labels)
    end

    display_text
  end

  # split affiliations out
  def split_affiliations(affiliations)
    affiliations_list = []

    Array(affiliations).reject { |a| a.blank? }.each do |aff|
      Array(DepartmentsService.term(aff)).join(';').split(';').each do |value|
        affiliations_list.push(value.squish!)
      end
    end

    affiliations_list.uniq
  end
end
