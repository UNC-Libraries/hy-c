# [hyc-override] https://github.com/samvera/hydra-head/blob/v12.1.0/hydra-access-controls/app/models/concerns/hydra/access_controls/visibility.rb
Hydra::AccessControls::Visibility.module_eval do
  alias_method :original_visibility, :visibility
  def visibility
    # [hyc-override] Default to the most permissive visibility for new records
    return Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC if self.new_record?
    original_visibility
  end
end