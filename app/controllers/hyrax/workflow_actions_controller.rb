# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/controllers/hyrax/workflow_actions_controller.rb
module Hyrax
  class WorkflowActionsController < ApplicationController
    DEFAULT_FORM_CLASS = Hyrax::Forms::WorkflowActionForm

    ##
    # @!attribute [r] curation_concern
    #   @api private
    #   @return [Hyrax::Resource]
    attr_reader :curation_concern

    # [hyc-override] defaulting to AF objects. This override can be removed
    # once https://github.com/samvera/hyrax/pull/5915 is released
    resource_klass = Hyrax.config.use_valkyrie? ? Hyrax::Resource : ActiveFedora::Base
    load_resource class: resource_klass, instance_name: :curation_concern
    # [hyc-override] end override
    before_action :authenticate_user!

    # rubocop:disable GitHub/RailsControllerRenderPathsExist
    def update
      if workflow_action_form.save
        after_update_response
      else
        respond_to do |wants|
          wants.html { render 'hyrax/base/unauthorized', status: :unauthorized }
          wants.json { render_json_response(response_type: :unprocessable_entity, options: { errors: workflow_action_form.errors }) }
        end
      end
    end
    # rubocop:enable GitHub/RailsControllerRenderPathsExist

    private

    def workflow_action_form
      @workflow_action_form ||= DEFAULT_FORM_CLASS.new(
        current_ability: current_ability,
        work: curation_concern,
        attributes: workflow_action_params
      )
    end

    def workflow_action_params
      params.require(:workflow_action).permit(:name, :comment)
    end

    def after_update_response
      respond_to do |wants|
        wants.html { redirect_to [main_app, curation_concern], notice: "The #{curation_concern.human_readable_type} has been updated." }
        wants.json { render 'hyrax/base/show', status: :ok, location: polymorphic_path([main_app, curation_concern]) }
      end
    end
  end
end
