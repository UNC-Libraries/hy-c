# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/controllers/hyrax/my/works_controller.rb
Hyrax::My::WorksController.class_eval do
  private
  # [hyc-override] fix for https://github.com/samvera/hyrax/issues/5969
  def collections_service
    cloned = self.clone
    cloned.params = {}
    Hyrax::CollectionsService.new(cloned)
  end
end
