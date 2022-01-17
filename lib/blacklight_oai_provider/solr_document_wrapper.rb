# [hyc-override] Using single item search builder when finding object by identifer
module BlacklightOaiProvider
  class SolrDocumentWrapper < ::OAI::Provider::Model
    attr_reader :document_model, :timestamp_field, :solr_timestamp, :limit

    def initialize(controller, options = {})
      @controller      = controller
      @document_model  = @controller.blacklight_config.document_model
      @solr_timestamp  = document_model.timestamp_key
      @timestamp_field = 'timestamp' # method name used by ruby-oai
      @limit           = options[:limit] || 15
      @set             = options[:set_model] || BlacklightOaiProvider::SolrSet

      @set.controller = @controller
      @set.fields = options[:set_fields]
    end

    def sets
      @set.all
    end

    def earliest
      builder = @controller.search_builder.merge(fl: solr_timestamp, sort: "#{solr_timestamp} asc", rows: 1)
      response = @controller.repository.search(builder)
      response.documents.first.timestamp
    end

    def latest
      builder = @controller.search_builder.merge(fl: solr_timestamp, sort: "#{solr_timestamp} desc", rows: 1)
      response = @controller.repository.search(builder)
      response.documents.first.timestamp
    end

    def find(selector, options = {})
      return next_set(options[:resumption_token]) if options[:resumption_token]

      if selector == :all
        response = @controller.repository.search(conditions(options))

        if limit && response.total > limit
          return select_partial(BlacklightOaiProvider::ResumptionToken.new(options.merge(last: 0), nil, response.total))
        end

        response.documents
      else
        # [hyc-override] using search builder in order to allow for access controls to be applied
        query = @controller.single_item_search_builder(selector).query
        Rails.logger.debug("Finding a single result #{selector} #{query}")
        @controller.repository.search(query).documents.first
      end
    end

    def select_partial(token)
      records = @controller.repository.search(token_conditions(token)).documents

      raise ::OAI::ResumptionTokenException unless records

      OAI::Provider::PartialResult.new(records, token.next(token.last + limit))
    end

    def next_set(token_string)
      raise ::OAI::ResumptionTokenException unless limit

      token = BlacklightOaiProvider::ResumptionToken.parse(token_string)
      select_partial(token)
    end

    private

    def token_conditions(token)
      conditions(token.to_conditions_hash).merge(start: token.last)
    end

    def conditions(options) # conditions/query derived from options
      query = @controller.search_builder.merge(sort: "#{solr_timestamp} asc", rows: limit).query

      if options[:from].present? || options[:until].present?
        query.append_filter_query(
          "#{solr_timestamp}:[#{solr_date(options[:from])} TO #{solr_date(options[:until]).gsub('Z', '.999Z')}]"
        )
      end

      query.append_filter_query(@set.from_spec(options[:set])) if options[:set].present?
      query
    end

    def solr_date(time)
      if time.respond_to?(:xmlschema)
        time.utc.xmlschema # Force UTC.
      elsif time.blank?
        '*'
      else
        time.to_s
      end
    end
  end
end
