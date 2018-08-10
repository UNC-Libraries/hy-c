class AdvisorInput < MultiValueInput
  # Overriding method from hydra-editor:
  # We are actually just displaying a single value for each
  # field of a person, so we override this method
  # so that there is only one value.  (e.g. each person
  # only has one name and one affiliation on the form.)
  def collection
    @collection ||= begin
      val = object[attribute_name]
      val.reject { |value| value.to_s.strip.blank? } + ['']
      val.blank? ? default_value(attribute_name) : val
    end
  end

  def default_value(attr_name)
    defaults = { affiliation: ['UNC'] }
    defaults.fetch(attr_name, [''])
  end

  # Overriding method from hydra-editor:
  # Since we are just using a single value, we don't need to
  # wrap the fields with <ul> and <li> tags, so just yield
  # with no wrapper tags.
  def outer_wrapper
    yield
  end

  # Overriding method from hydra-editor:
  # Since we are just using a single value, we don't need to
  # wrap the fields with <ul> and <li> tags, so just yield
  # with no wrapper tags.
  def inner_wrapper
    yield
  end
end
