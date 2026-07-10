# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v5.2.0/app/services/hyrax/persist_directly_contained_output_file_service.rb
Hyrax::PersistDirectlyContainedOutputFileService.class_eval do
  def self.fileset_for_directives(directives)
    path = URI(directives.fetch(:url)).path
    id = path.sub(Hyrax.config.derivatives_path.to_s, '')
             .delete('/')
             .match(/^(.*)-\w*(\.\w+)*$/) { |m| m[1] }
    raise "Could not extract fileset id from path #{path}" unless id

    # [hyc-override] Use `use_valkyrie: false` to get back the ActiveFedora object, since it
    # needs to respond to `build_#{container}` from `directly_contains`.
    Hyrax.query_service.find_by_alternate_identifier(alternate_identifier: id, use_valkyrie: false)
  end
  private_class_method :fileset_for_directives
end
