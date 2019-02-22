class CatalogController < ApplicationController
  include Hydra::Catalog
  include Hydra::Controller::ControllerBehavior
  include BlacklightOaiProvider::Controller

  # This filter applies the hydra access controls
  before_action :enforce_show_permissions, only: :show

  # Allow all search options when in read-only mode
  skip_before_action :check_read_only

  def self.uploaded_field
    solr_name('system_create', :stored_sortable, type: :date)
  end

  def self.modified_field
    solr_name('system_modified', :stored_sortable, type: :date)
  end

  configure_blacklight do |config|
    config.show.tile_source_field = :content_metadata_image_iiif_info_ssm
    config.show.partials.insert(1, :openseadragon)
    config.search_builder_class = Hyrax::CatalogSearchBuilder

    # Show gallery view
    # config.view.gallery.partials = [:index_header, :index]
    config.view.masonry.partials = [:index]
    config.view.slideshow.partials = [:index]

    ## Default parameters to send to solr for all search-like requests. See also SolrHelper#solr_search_params
    config.default_solr_params = {
      qt: "search",
      rows: 10,
      qf: "title_tesim description_tesim creator_tesim keyword_tesim"
    }

    # solr field configuration for document/show views
    config.index.title_field = solr_name("title", :stored_searchable)
    config.index.display_type_field = solr_name("has_model", :symbol)
    config.index.thumbnail_field = 'thumbnail_path_ss'

    # solr fields that will be treated as facets by the blacklight application
    #   The ordering of the field names is the order of the display

    config.add_facet_field solr_name("advisor_label", :facetable), label: "Advisor", limit: 5
    config.add_facet_field solr_name('member_of_collections', :symbol), limit: 5, label: 'Collection'
    config.add_facet_field solr_name("creator_label", :facetable), label: "Creator", limit: 5
    config.add_facet_field solr_name("date_issued", :facetable), label: "Date", limit: 5
    config.add_facet_field solr_name("keyword", :facetable), limit: 5
    config.add_facet_field solr_name("language", :facetable), helper_method: :language_links_facets, limit: 5
    config.add_facet_field solr_name("resource_type", :facetable), label: "Resource Type", limit: 5
    config.add_facet_field solr_name("subject", :facetable), limit: 5
    config.add_facet_field solr_name("file_format", :facetable), limit: 5
    config.add_facet_field solr_name("depositor", :facetable), limit: 5
    config.add_facet_field solr_name("based_near_label", :facetable), limit: 5

    # UNC Custom
    config.add_facet_field solr_name("affiliation_label", :facetable), label: "Departments", limit: 5
    config.add_facet_field solr_name("edition", :facetable), label: "Version", limit: 5
    config.add_facet_field solr_name("language_label", :facetable), label: "Language", limit: 5


    # The generic_type isn't displayed on the facet list
    # It's used to give a label to the filter that comes from the user profile
    config.add_facet_field solr_name("generic_type", :facetable), if: false

    # Have BL send all facet field names to Solr, which has been the default
    # previously. Simply remove these lines if you'd rather use Solr request
    # handler defaults, or have no facets.
    config.add_facet_fields_to_solr_request!

    # solr fields to be displayed in the index (search results) view
    #   The ordering of the field names is the order of the display
    config.add_index_field solr_name("title", :stored_searchable), label: "Title", itemprop: 'name', if: false
    config.add_index_field solr_name("creator_label", :stored_searchable), label: "Creator", itemprop: 'creator', link_to_search: solr_name("creator", :facetable)
    config.add_index_field solr_name("date_created", :stored_searchable), itemprop: 'dateCreated', label: "Date created"
    config.add_index_field solr_name("date_issued", :stored_searchable), label: "Date of publication"
    config.add_index_field solr_name("abstract", :stored_searchable), label: "Abstract"
    config.add_index_field solr_name("resource_type", :stored_searchable), label: "Resource type", link_to_search: solr_name("resource_type", :facetable)
    config.add_index_field solr_name("based_near_label", :stored_searchable), itemprop: 'contentLocation', link_to_search: solr_name("based_near_label", :facetable)

    # solr fields to be displayed in the show (single result) view
    #   The ordering of the field names is the order of the display
    config.add_show_field solr_name("title", :stored_searchable)
    config.add_show_field solr_name("creator_label", :stored_searchable), label: "Creator"
    config.add_show_field solr_name("date_created", :stored_searchable), label: "Date created"
    config.add_show_field solr_name("date_issued", :stored_searchable), label: "Date of publication"
    config.add_show_field solr_name("abstract", :stored_searchable)
    config.add_show_field solr_name("resource_type", :stored_searchable), label: "Resource type"
    config.add_show_field solr_name("based_near_label", :stored_searchable), label: "Location"

    # Search fields
    # include all fields available to allow searching across all attributes
    config.add_show_field solr_name("academic_concentration", :stored_searchable), label: "Academic Concentration"
    config.add_show_field solr_name("access", :stored_searchable), label: "Access"
    config.add_show_field solr_name("affiliation", :stored_searchable), label: "Departments", link_to_search: solr_name("affiliation", :facetable)
    config.add_show_field solr_name("affiliation_label", :stored_searchable)
    config.add_show_field solr_name("alternative_title", :stored_searchable), label: "Alternative Title"
    config.add_show_field solr_name("award", :stored_searchable), label: "Award"
    config.add_show_field solr_name("bibliographic_citation", :stored_searchable), label: "Bibliographic Citation"
    config.add_show_field solr_name("conference_name", :stored_searchable), label: "Conference Name"
    config.add_show_field solr_name("copyright_date", :stored_searchable), label: "Copyright Date"
    config.add_show_field solr_name("date_other", :stored_searchable), label: "Date Other"
    config.add_show_field solr_name("degree", :stored_searchable), label: "Degree"
    config.add_show_field solr_name("degree_granting_institution", :stored_searchable), label: "Degree Granting Institution"
    config.add_show_field solr_name("deposit_record", :stored_searchable), label: "Deposit Record"
    config.add_show_field solr_name("description", :stored_searchable), label: "Description"
    config.add_show_field solr_name("dcmi_type", :stored_searchable), label: "Type"
    config.add_show_field solr_name("digital_collection", :stored_searchable), label: "Digital Collection"
    config.add_show_field solr_name("discipline", :stored_searchable), label: "Discipline"
    config.add_show_field solr_name("doi", :stored_searchable), label: "DOI"
    config.add_show_field solr_name("edition", :stored_searchable), label: "Edition"
    config.add_show_field solr_name("extent", :stored_searchable), label: "Extent"
    config.add_show_field solr_name("graduation_year", :stored_searchable), label: "Graduation Year"
    config.add_show_field solr_name("identifier", :stored_searchable), label: "Identifier"
    config.add_show_field solr_name("isbn", :stored_searchable), label: "ISBN"
    config.add_show_field solr_name("issn", :stored_searchable), label: "ISSN"
    config.add_show_field solr_name("journal_issue", :stored_searchable), label: "Journal Issue"
    config.add_show_field solr_name("journal_title", :stored_searchable), label: "Journal Title"
    config.add_show_field solr_name("journal_volume", :stored_searchable), label: "Journal Volume"
    config.add_show_field solr_name("keyword", :stored_searchable), label: "Keyword"
    config.add_show_field solr_name("kind_of_data", :stored_searchable), label: "Kind of Data"
    config.add_show_field solr_name("language_label", :stored_searchable), label: "Language Label"
    config.add_show_field solr_name("last_modified_date", :stored_searchable), label: "Last Modified Date"
    config.add_show_field solr_name("license_label", :stored_searchable), label: "License Label"
    config.add_show_field solr_name("medium", :stored_searchable), label: "Medium"
    config.add_show_field solr_name("methodology", :stored_searchable), label: "Methodology"
    config.add_show_field solr_name("note", :stored_searchable), label: "Note"
    config.add_show_field solr_name("orcid_label", :stored_searchable), label: "ORCID"
    config.add_show_field solr_name("other_affiliation_label", :stored_searchable), label: "Other Affiliation"
    config.add_show_field solr_name("page_end", :stored_searchable), label: "Page End"
    config.add_show_field solr_name("page_start", :stored_searchable), label: "Page Start"
    config.add_show_field solr_name("peer_review_status", :stored_searchable), label: "Peer Review Status"
    config.add_show_field solr_name("person_label", :stored_searchable), label: "Person"
    config.add_show_field solr_name("place_of_publication", :stored_searchable), label: "Place of Publication"
    config.add_show_field solr_name("publisher", :stored_searchable), label: "Publisher"
    config.add_show_field solr_name("publisher_version", :stored_searchable), label: "Publisher Version"
    config.add_show_field solr_name("rights_holder", :stored_searchable), label: "Rights Holder"
    config.add_show_field solr_name("rights_statement_label", :stored_searchable), label: "Rights Statement Label"
    config.add_show_field solr_name("series", :stored_searchable), label: "Series"
    config.add_show_field solr_name("source", :stored_searchable), label: "Source"
    config.add_show_field solr_name("subject", :stored_searchable), label: "Subject"
    config.add_show_field solr_name("table_of_contents", :stored_searchable), label: "Table of Contents"
    config.add_show_field solr_name("url", :stored_searchable), label: "Url"
    config.add_show_field solr_name("use", :stored_searchable), label: "Use"

    # "fielded" search configuration. Used by pulldown among other places.
    # For supported keys in hash, see rdoc for Blacklight::SearchFields
    #
    # Search fields will inherit the :qt solr request handler from
    # config[:default_solr_parameters], OR can specify a different one
    # with a :qt key/value. Below examples inherit, except for subject
    # that specifies the same :qt as default for our own internal
    # testing purposes.
    #
    # The :key is what will be used to identify this BL search field internally,
    # as well as in URLs -- so changing it after deployment may break bookmarked
    # urls.  A display label will be automatically calculated from the :key,
    # or can be specified manually to be different.
    #
    # This one uses all the defaults set by the solr request handler. Which
    # solr request handler? The one set in config[:default_solr_parameters][:qt],
    # since we aren't specifying it otherwise.
    config.add_search_field('all_fields', label: 'All Fields') do |field|
      all_names = config.show_fields.values.map(&:field).join(" ")
      title_name = solr_name("title", :stored_searchable)
      field.solr_parameters = {
        qf: "#{all_names} file_format_tesim all_text_timv",
        pf: title_name.to_s
      }
    end

    # Now we see how to over-ride Solr request handler defaults, in this
    # case for a BL "search field", which is really a dismax aggregate
    # of Solr search fields.
    # creator, title, description, publisher, date_created,
    # subject, language, resource_type, format, identifier, based_near,
    config.add_search_field('contributor') do |field|
      # solr_parameters hash are sent to Solr as ordinary url query params.

      # :solr_local_parameters will be sent using Solr LocalParams
      # syntax, as eg {! qf=$title_qf }. This is neccesary to use
      # Solr parameter de-referencing like $title_qf.
      # See: http://wiki.apache.org/solr/LocalParams
      solr_name = solr_name("contributor", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('creator') do |field|
      solr_name = solr_name("creator", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('title') do |field|
      solr_name = solr_name("title", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('description') do |field|
      solr_name = solr_name("description", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('publisher') do |field|
      solr_name = solr_name("publisher", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('date_created') do |field|
      solr_name = solr_name("created", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('subject') do |field|
      solr_name = solr_name("subject", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('language') do |field|
      solr_name = solr_name("language", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('resource_type') do |field|
      solr_name = solr_name("resource_type", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('format') do |field|
      solr_name = solr_name("format", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('identifier') do |field|
      solr_name = solr_name("id", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('based_near') do |field|
      field.label = "Location"
      solr_name = solr_name("based_near_label", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('keyword') do |field|
      solr_name = solr_name("keyword", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('depositor') do |field|
      solr_name = solr_name("depositor", :symbol)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    config.add_search_field('rights_statement') do |field|
      solr_name = solr_name("rights_statement", :stored_searchable)
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end

    # "sort results by" select (pulldown)
    # label in pulldown is followed by the name of the SOLR field to sort by and
    # whether the sort is ascending or descending (it must be asc or desc
    # except in the relevancy case).
    # label is key, solr field is value
    config.add_sort_field "score desc, #{uploaded_field} desc", label: "relevance"
    config.add_sort_field "#{uploaded_field} desc", label: "date uploaded \u25BC"
    config.add_sort_field "#{uploaded_field} asc", label: "date uploaded \u25B2"
    config.add_sort_field "#{modified_field} desc", label: "date modified \u25BC"
    config.add_sort_field "#{modified_field} asc", label: "date modified \u25B2"

    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 5

    config.oai = {
        provider: {
            repository_name: 'Carolina Digital Repository',
            repository_url: 'https://localhost:4040',
            record_prefix: '',
            admin_email: 'admin@example.com'
        },
        document: {
            limit: 25,
            set_model: LanguageSet,
            set_fields: [{ label: 'language', solr_field: 'language_label_tesim' }]
        }
    }
  end

  # disable the bookmark control from displaying in gallery view
  # Hyrax doesn't show any of the default controls on the list view, so
  # this method is not called in that context.
  def render_bookmarks_control?
    false
  end
end
