# frozen_string_literal: true

Rails.application.config.after_initialize do
  # RuntimeRegistry stores the default index per thread, so initialize each entry with the pooled repository.
  Blacklight.singleton_class.prepend(Module.new do
    def default_index
      repository = Blacklight::RuntimeRegistry.connection
      return repository if repository.is_a?(Hyc::PooledSolrRepository)

      Blacklight::RuntimeRegistry.connection =
        Hyc::PooledSolrRepository.new(default_configuration)
    end
  end)
end
