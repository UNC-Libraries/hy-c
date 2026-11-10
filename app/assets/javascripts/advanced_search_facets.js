// Enhance the native multi-selects while retaining their standard form values.
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
          return '<div>' + escape(data.label || (data.$option && data.$option.dataset.label) || data.text) + '</div>';
        }
      }
    });
    // Tom Select creates its own combobox and list, so label those as well.
    select.focus_node.setAttribute('aria-label', element.getAttribute('aria-label'));
    select.dropdown_content.setAttribute('aria-label', element.getAttribute('aria-label'));

    let page = 0;
    let loading = false;
    let hasMore = true;
    let form = element.closest('form');
    let loadMore = function () {
      if (loading || !hasMore) return;

      loading = true;
      // Reuse the form's query and other filters so each page reflects the current advanced-search context.
      let params = new URLSearchParams(new FormData(form));
      params.set('advanced_search_facet', '1');
      params.set('facet.page', String(page + 1));
      params.delete('f[' + element.dataset.facetKey + '][]');
      params.delete('f_inclusive[' + element.dataset.facetKey + '][]');
      let loaded = false;

      fetch(element.dataset.facetUrl + '?' + params.toString(), {
        headers: { Accept: 'application/json' }
      })
        .then(function (response) {
          if (!response.ok) throw new Error('Facet request failed with status ' + response.status);
          return response.json();
        })
        .then(function (data) {
          let facets = data.response.facets;
          // Add returned options to the native select so both Tom Select and normal form submission see them.
          facets.items.forEach(function (item) {
            if (Object.prototype.hasOwnProperty.call(select.options, item.value)) return;

            let label = item.label || item.value;
            let text = label + ' (' + new Intl.NumberFormat().format(item.hits) + ')';
            select.addOption({ value: item.value, text: text, label: label });
            let option = Array.from(element.options).find(function (candidate) {
              return candidate.value === item.value;
            });
            if (option) option.dataset.label = label;
          });
          page += 1;
          // The server requests one sentinel item; a full page means more values may be available.
          hasMore = facets.items.length === facets.limit;
          loaded = true;

          let error = select.wrapper.nextElementSibling;
          if (error && error.classList.contains('advanced-search-facet-load-error')) error.hidden = true;
        })
        .catch(function (error) {
          // Keep the dropdown usable and show a visible error instead of silently ending pagination.
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
          let dropdown = select.dropdown_content;
          if (loaded && select.isOpen && dropdown.scrollTop + dropdown.clientHeight >= dropdown.scrollHeight - 20) loadMore();
        });
    };

    select.dropdown_content.addEventListener('scroll', function () {
      let dropdown = select.dropdown_content;
      // Fetch the next page before the user reaches the end of the current options.
      if (dropdown.scrollTop + dropdown.clientHeight >= dropdown.scrollHeight - 20) loadMore();
    });
    select.on('dropdown_open', loadMore);
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
