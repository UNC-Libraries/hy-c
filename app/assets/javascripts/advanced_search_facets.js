// Enhance the native multi-selects while retaining their standard form values.
// Bootstrap emits this event once a facet panel has finished opening.
$(document).on('shown.bs.collapse', '.collapse', function () {
  this.querySelectorAll('.advanced-search-multi-select').forEach(function (element) {
    if (element.loadFacetValues) element.loadFacetValues();
  });
});

document.addEventListener('turbolinks:load', function () {
  document.querySelectorAll('.advanced-search-multi-select').forEach(function (element) {
    if (element.tomselect) return;

    let select = new TomSelect(element, {
      // Show checkboxes in the dropdown and provide a button to clear selections.
      plugins: ['checkbox_options', 'clear_button', 'remove_button'],
      // Include values beyond Tom Select's default option limit.
      maxOptions: null,
      // Keep selected options visible so their checkboxes can be unchecked.
      hideSelected: false,
      render: {
        // data contains the selected option; escape safely encodes its label as HTML.
        item: function (data, escape) {
          // Selected items show the facet label without the option's result count.
          return '<div>' + escape((data.$option && data.$option.dataset.label) || data.label || data.text) + '</div>';
        }
      }
    });
    // Tom Select creates its own combobox and list, so label those as well.
    select.focus_node.setAttribute('aria-label', element.getAttribute('aria-label'));
    select.dropdown_content.setAttribute('aria-label', element.getAttribute('aria-label'));

    // Load this field's values only when its containing advanced-search facet is expanded.
    let page = 0;
    let loading = false;
    let hasMore = true;
    element.loadFacetValues = function () {
      if (loading || !hasMore) return;

      loading = true;
      let params = new URLSearchParams(new FormData(element.closest('form')));
      params.set('advanced_search_facet', '1');
      params.set('facet.page', String(page + 1));
      params.delete('f[' + element.dataset.facetKey + '][]');
      params.delete('f_inclusive[' + element.dataset.facetKey + '][]');

      fetch(element.dataset.facetUrl + '?' + params.toString(), {
        headers: { Accept: 'application/json' }
      })
        .then(function (response) {
          if (!response.ok) throw new Error('Facet request failed with status ' + response.status);
          return response.json();
        })
        .then(function (data) {
          let facets = data.response.facets;
          facets.items.forEach(function (item) {
            if (Object.prototype.hasOwnProperty.call(select.options, item.value)) return;

            let label = item.label || item.value;
            select.addOption({
              value: item.value,
              text: label + ' (' + new Intl.NumberFormat().format(item.hits) + ')',
              label: label
            });
            let option = Array.from(element.options).find(function (candidate) {
              return candidate.value === item.value;
            });
            if (option) option.dataset.label = label;
          });
          page += 1;
          hasMore = facets.items.length === facets.limit;
        })
        .catch(function (error) {
          let message = select.wrapper.nextElementSibling;
          if (!message || !message.classList.contains('advanced-search-facet-load-error')) {
            message = document.createElement('div');
            message.className = 'advanced-search-facet-load-error alert alert-danger';
            message.setAttribute('role', 'alert');
            select.wrapper.insertAdjacentElement('afterend', message);
          }
          message.textContent = element.dataset.facetLoadError;
          message.hidden = false;
          console.error(error);
        })
        .finally(function () {
          loading = false;
        });
    };

    // Subsequent values load as the user scrolls to the end of the select dropdown.
    select.dropdown_content.addEventListener('scroll', function () {
      let dropdown = select.dropdown_content;
      if (dropdown.scrollTop + dropdown.clientHeight >= dropdown.scrollHeight - 20) element.loadFacetValues();
    });
    select.on('dropdown_open', element.loadFacetValues);
  });

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
  // Cache the native controls so Turbolinks can recreate the widgets and listeners.
  document.querySelectorAll('.advanced-search-multi-select').forEach(function (element) {
    if (element.tomselect) element.tomselect.destroy();
  });
  document.querySelectorAll('form.advanced').forEach(function (form) {
    delete form.dataset.facetLimitBound;
    let error = form.querySelector('.advanced-search-facet-error');
    if (error) error.hidden = true;
    let valueError = form.querySelector('.advanced-search-facet-value-error');
    if (valueError) valueError.hidden = true;
  });
});
