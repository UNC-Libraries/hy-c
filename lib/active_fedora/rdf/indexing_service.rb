# [hyc-override] Storing person display and label information in solr
module ActiveFedora::RDF
  # Responsible for generating the solr document (via #generate_solr_document) of the
  # given object.
  #
  # @see ActiveFedora::Indexing
  # @see ActiveFedora::IndexingService

  class IndexingService
    include Solrizer::Common
    attr_reader :object, :index_config

    # [hyc-override] fields in person class
    class_attribute :person_fields
    self.person_fields = ['advisors', 'arrangers', 'composers', 'contributors', 'creators', 'project_directors', 'researchers',
                          'reviewers', 'translators']

    # @param [#resource, #rdf_subject] obj the object to build an solr document for. Its class must respond to 'properties'
    # @param [ActiveFedora::Indexing::Map] index_config the configuration to use to map object values to index document values
    def initialize(obj, index_config = nil)
      unless index_config
        Deprecation.warn(self, "initializing ActiveFedora::RDF::IndexingService without an index_config is deprecated and will be removed in ActiveFedora 13.0")
        index_config = obj.class.index_config
      end
      @object = obj
      @index_config = index_config

      # [hyc-override] initialize label variables
      @person_label = []
      @creator_label = []
      @advisor_label = []
      @orcid_label = []
      @affiliation_label = []
      @other_affiliation_label = []
    end

    # Creates a solr document hash for the rdf assertions of the {#object}
    # @yield [Hash] yields the solr document
    # @return [Hash] the solr document
    def generate_solr_document(prefix_method = nil)
      solr_doc = add_assertions(prefix_method)
      yield(solr_doc) if block_given?
      solr_doc
    end

    protected

    # [hyc-override] store display and label fields in solr
    # Built in based_near attributes requires full field info
    def add_assertions(prefix_method, solr_doc = {})
      fields.each do |field_key, field_info|
        if person_fields.include? field_key.to_s
          if !field_info.values.blank?
            field_to_use = field_key == 'based_near' ? field_info : field_info.behaviors
            append_to_solr_doc(solr_doc,
                               solr_document_field_name((field_key.to_s[0...-1]+'_display').to_sym, prefix_method),
                               field_to_use,
                               build_person_display(field_key, field_info.values))
          end
        else
          solr_field_key = solr_document_field_name(field_key, prefix_method)
          field_info.values.each do |val|
            field_to_use = solr_field_key == 'based_near' ? field_info : field_info.behaviors
            value = val

            if solr_field_key == 'date_created'
              if val.is_a? Date
                value = val
              elsif val.is_a? DateTime
                value =  Hyc::EdtfConvert.convert_from_edtf(val.strftime('%Y-%m-%d'))
              else
                value =  Hyc::EdtfConvert.convert_from_edtf(Date.parse(val).strftime('%Y-%m-%d'))
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

      solr_doc
    end

    # Override this in order to allow one field to be expanded into more than one:
    #   example:
    #     def append_to_solr_doc(solr_doc, field_key, field_info, val)
    #       ActiveFedora.index_field_mapper.set_field(solr_doc, 'lcsh_subject_uri', val.to_uri, :symbol)
    #       ActiveFedora.index_field_mapper.set_field(solr_doc, 'lcsh_subject_label', val.to_label, :searchable)
    #     end
    # [hyc-override] replaced field_info with behaviors in params
    def append_to_solr_doc(solr_doc, solr_field_key, behaviors, val)
      self.class.create_and_insert_terms(solr_field_key,
                                                               solr_document_field_value(val),
                                                               behaviors,
                                                               solr_doc)
    end

    def solr_document_field_name(field_key, prefix_method)
      if prefix_method
        prefix_method.call(field_key)
      else
        field_key.to_s
      end
    end

    def solr_document_field_value(val)
      case val
        when ::RDF::URI
          val.to_s
        when ActiveTriples::Resource
          val.node? ? val.rdf_label : val.rdf_subject.to_s
        else
          val
      end
    end

    def resource
      object.resource
    end

    # returns the field map instance
    def fields
      field_map_class.new do |field_map|
        index_config.each { |name, index_field_config| field_map.insert(name, index_field_config, object) }
      end
    end

    # Override this method to use your own FieldMap class for custom indexing of objects and properties
    def field_map_class
      ActiveFedora::RDF::FieldMap
    end

    # [hyc-override] add method for serializing display data
    private

      def build_person_display(field_key, people)
        displays = []
        people.each do |person|
          display_text = []
          if !Array(person['name']).first.blank?
            display_text << Array(person['name']).first
            @person_label.push(Array(person['name']))
            if field_key.to_s == 'creators'
              @creator_label.push(Array(person['name']))
            elsif field_key.to_s == 'advisors'
              @advisor_label.push(Array(person['name']))
            end

            display_text << "ORCID: #{Array(person['orcid']).first}" if !Array(person['orcid']).first.blank?
            @orcid_label.push(Array(person['orcid']))

            affiliations = split_affiliations(person['affiliation'])
            if !affiliations.blank?
              display_text << "Affiliation: #{affiliations.join(', ')}"
              @affiliation_label.push(Array(person['affiliation']))
            end

            display_text << "Other Affiliation: #{Array(person['other_affiliation']).first}" if !Array(person['other_affiliation']).first.blank?
            @other_affiliation_label.push(Array(person['other_affiliation']))

            displays << display_text.join('||')
          end
        end
        displays.flatten
      end

      # split affiliations out
      def split_affiliations(affiliations)
        affiliations_list = []

        Array(affiliations).reject { |a| a.blank? }.each do |aff|
          Array(DepartmentsService.label(aff)).join(';').split(';').each do |value|
            affiliations_list.push(value.squish!)
          end
        end

        affiliations_list.uniq
      end
  end
end
