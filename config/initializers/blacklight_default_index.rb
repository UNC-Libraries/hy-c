# frozen_string_literal: true

Rails.application.config.after_initialize do
  Blacklight.default_index = Hyc::PooledSolrRepository.new(Blacklight.default_configuration)
  Rails.logger.info do
    repository = Blacklight.default_index
    connection = repository.connection
    adapter = connection.instance_variable_get(:@connection).builder.adapter.klass

    "[Solr] Blacklight.default_index=#{repository.class} adapter=#{adapter}"
  end
end
