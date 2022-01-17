# [hyc-override] allow admins to attach child owned by another user
module Hyrax
  module My
    # Search builder for things that the current user has deposited and has edit access to
    # @abstract
    class SearchBuilder < ::SearchBuilder
      # Check for edit access
      include Hyrax::My::SearchBuilderBehavior
      self.default_processor_chain += [:show_only_resources_deposited_by_current_user]

      # [hyc-override] filter by depositor if not admin
      # adds a filter to the solr_parameters that filters the documents the current user
      # has deposited
      # @param [Hash] solr_parameters
      def show_only_resources_deposited_by_current_user(solr_parameters)
        user_id = ::User.where(uid: current_user_key).first.id
        usergroup = Role.select('name').joins(:roles_users).where('roles_users.user_id = ?', user_id)
        solr_parameters[:fq] ||= []
        if !(usergroup.map { |role| role.name }.include? 'admin')
          solr_parameters[:fq] += [
              ActiveFedora::SolrQueryBuilder.construct_query_for_rel(depositor: current_user_key)
          ]
        end
      end
    end
  end
end
