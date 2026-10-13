# frozen_string_literal: true
# [hyc-override] Add alt_text to terms for FileSetEditForm.
# https://github.com/samvera/hyrax/blob/hyrax-v5.3.1/app/forms/hyrax/forms/file_set_edit_form.rb
Hyrax::Forms::FileSetEditForm.class_eval do
    self.terms += [:alt_text]
end
