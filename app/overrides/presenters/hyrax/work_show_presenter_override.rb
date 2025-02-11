# frozen_string_literal: true
# [hyc-override] Overriding helper in order to add doi to citation
# https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/presenters/hyrax/work_show_presenter.rb
Hyrax::WorkShowPresenter.class_eval do
  include Hyrax::SharedDelegates

  # [hyc-override] Add default scholarly? method
  # Indicates if the work is considered scholarly according to google scholar
  # This method is not defined in hyrax, but it is referenced by GoogleScholarPresenter
  def scholarly?
    false
  end
end
