# frozen_string_literal: true
# Builder for search that is restricted to the current user
class RestrictedSingleResultBuilder < ::SearchBuilder
  self.default_processor_chain += [:add_access_controls_to_solr_params, :find_one]

  def initialize(controller, id)
    super(controller)
    @id = id
  end

  def find_one(solr_parameters)
    solr_parameters[:fq] << "id:#{@id}"
  end
end
