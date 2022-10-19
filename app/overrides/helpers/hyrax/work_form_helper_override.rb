# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/helpers/hyrax/work_form_helper.rb
Hyrax::WorkFormHelper.module_eval do
  def form_tabs_for(form:)
    if form.instance_of? Hyrax::Forms::BatchUploadForm
      %w[files metadata relationships]
    else
      # [hyc-override] remove files tab.
      %w[metadata relationships]
    end
  end
end