$(document).on('click', '.advanced-facet-picker', function (event) {
  event.preventDefault();
  let url = new URL(this.formAction, window.location.href);
  url.searchParams.set('advanced_facet_picker', '1');
  $.ajax({ url: url.toString() }).fail(Blacklight.modal.onFailure).done(Blacklight.modal.receiveAjax);
});

$(document).on('loaded.blacklight.blacklight-modal', '#blacklight-modal', function () {
  let picker = this.querySelector('.advanced-facet-picker-form');
  if (!picker) return;
  let list = Array.from(document.querySelectorAll('form.advanced .advanced-search-facet-values')).find(function (element) {
    return element.dataset.facetField === picker.dataset.facetField;
  });
  if (!list) return;
  let selected = Array.from(list.querySelectorAll('input:checked')).map(function (input) { return input.value; });
  picker.querySelectorAll('input[type=checkbox]').forEach(function (input) {
    input.checked = selected.includes(input.value);
  });
});

$(document).on('change', '#blacklight-modal .advanced-facet-picker-form input[type=checkbox]', function () {
  let picker = this.closest('.advanced-facet-picker-form');
  let list = Array.from(document.querySelectorAll('form.advanced .advanced-search-facet-values')).find(function (element) {
    return element.dataset.facetField === picker.dataset.facetField;
  });
  if (!list) return;
  let control = Array.from(list.querySelectorAll('input[type=checkbox]')).find((input) => input.value === this.value);
  if (!control) {
    let item = document.createElement('li');
    let label = document.createElement('label');
    control = document.createElement('input');
    control.type = 'checkbox';
    control.name = this.name;
    control.value = this.value;
    label.append(control, document.createTextNode(' ' + this.closest('li').querySelector('.facet-label').textContent));
    item.append(label);
    list.append(item);
  }
  control.checked = this.checked;
});

$(document).on('submit', '#blacklight-modal .advanced-facet-picker-form', function (event) {
  event.preventDefault();
  let submitter = event.originalEvent.submitter;
  if (!submitter) return;
  if (submitter.name === 'advanced_facet_apply') {
    $('#blacklight-modal').modal('hide');
    return;
  }
  let url = new URL(this.action, window.location.href);
  url.searchParams.set('advanced_facet_picker', '1');
  url.searchParams.set('facet.page', submitter.value);
  url.searchParams.set('facet.sort', this.elements['facet.sort'].value);
  $.ajax({ url: url.toString() }).fail(Blacklight.modal.onFailure).done(Blacklight.modal.receiveAjax);
});

document.addEventListener('turbolinks:load', function () {
  document.querySelectorAll('form.advanced').forEach(function (form) {
    if (form.dataset.facetLimitBound) return;
    form.dataset.facetLimitBound = 'true';
    form.addEventListener('submit', function (event) {
      let facets = form.querySelector('#advanced_search_facets');
      if (!facets) return;

      // Count submitted values by field, including existing ordinary and inclusive filters.
      let fields = new Map();
      new FormData(form).forEach(function (value, name) {
        // Match names like "f[name][]" or "f_inclusive[name][]".
        let match = name.match(/^f(?:_inclusive)?\[([^\]]+)]\[]$/);
        // If the name matches and its value isn't blank, add the captured field name
        if (match && value.trim()) {
          fields.set(match[1], (fields.get(match[1]) || 0) + 1);
        }
      });

      // The form's data-max-facet-fields comes from the server's search limit.
      let error = form.querySelector('.advanced-search-facet-error');
      let valueError = form.querySelector('.advanced-search-facet-value-error');
      error.hidden = fields.size <= Number(facets.dataset.maxFacetFields);
      valueError.hidden = !Array.from(fields.values()).some(function (count) {
        return count > Number(facets.dataset.maxFacetValues);
      });
      if (!error.hidden || !valueError.hidden) {
        event.preventDefault();
        // Stop propagation of the event to prevent Rails UJS from disabling the submit button even for a canceled submission.
        event.stopPropagation();
        (error.hidden ? valueError : error).scrollIntoView({ block: 'center' });
      }
    });
  });
});

document.addEventListener('turbolinks:before-cache', function () {
  document.querySelectorAll('form.advanced').forEach(function (form) {
    delete form.dataset.facetLimitBound;
    let error = form.querySelector('.advanced-search-facet-error');
    if (error) error.hidden = true;
    let valueError = form.querySelector('.advanced-search-facet-value-error');
    if (valueError) valueError.hidden = true;
  });
});
