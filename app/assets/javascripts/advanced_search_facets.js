// Enhance the native multi-selects while retaining their standard form values.
document.addEventListener('turbolinks:load', function () {
  document.querySelectorAll('.advanced-search-multi-select').forEach(function (element) {
    if (element.tomselect) return;

    let error = element.parentElement.querySelector('.advanced-facet-load-error');
    let limited = false;
    let activeRequest;
    let destroyed = false;
    let retryState;
    element.hidden = false;
    let moreFacets = element.parentElement.querySelector('.more_facets');
    if (moreFacets) moreFacets.hidden = true;
    let select = new TomSelect(element, {
      // Show checkboxes in the dropdown and provide a button to clear selections.
      plugins: ['checkbox_options', 'clear_button', 'remove_button', 'virtual_scroll'],
      // Include values beyond Tom Select's default option limit.
      maxOptions: null,
      // Keep selected options visible so their checkboxes can be unchecked.
      hideSelected: false,
      // Cancel the previous query as soon as the user types so its response
      // cannot replace the options for the new query.
      onType: function () {
        limited = false;
        if (activeRequest) activeRequest.abort();
      },
      // Build the first modal-page URL for a query. The virtual-scroll plugin
      // stores subsequent page URLs separately for each query string.
      firstUrl: function (query) {
        let url = new URL(element.dataset.facetUrl, window.location.href);
        url.searchParams.set('facet_query', query);
        url.searchParams.set('facet.page', '1');
        return url.toString();
      },
      // Fetch the page queued by virtual_scroll, append options on scroll, and
      // retain prior options when retrying a failed request. A completed or
      // aborted request must invoke the callback at most once.
      load: function (query, callback) {
        let control = this;
        let url = control.getUrl(query);
        let retainedOptions = retryState && retryState.query === query ? retryState.options : [];
        retryState = null;
        let request = new AbortController();
        let finished = false;
        // Release Tom Select's loading state exactly once, unless the widget
        // has already been destroyed during Turbolinks navigation.
        function finish(options) {
          if (finished || destroyed) return;
          finished = true;
          callback(options);
        }
        request.signal.addEventListener('abort', function () { finish(); });
        activeRequest = request;
        fetch(url, { headers: { Accept: 'application/json' }, signal: request.signal })
          // Reject non-success responses so they follow the visible retry path.
          .then(function (response) {
            if (!response.ok) throw new Error('Facet request failed: ' + response.status);
            return response.json();
          })
          // Ignore stale responses, register the next page, and deliver the
          // formatted options returned by the server to Tom Select.
          .then(function (data) {
            if (destroyed || finished) return;
            if (request.signal.aborted || control.lastValue !== query) {
              finish();
              return;
            }
            if (activeRequest === request) activeRequest = null;
            error.hidden = true;
            limited = data.limited;
            if (data.next_page) {
              let nextUrl = new URL(url);
              nextUrl.searchParams.set('facet.page', data.next_page);
              control.setNextUrl(query, nextUrl.toString());
            }
            finish(retainedOptions.concat(data.options));
          })
          // Restore the failed URL for retry and show an error, except when
          // cancellation is intentional or the control no longer exists.
          .catch(function (failure) {
            if (destroyed || finished) return;
            if (activeRequest === request) activeRequest = null;
            if (request.signal.aborted) {
              finish();
              return;
            }
            console.error('Unable to load advanced search facets', failure);
            control.setNextUrl(query, url);
            error.hidden = false;
            finish();
          });
      },
      render: {
        // data contains the selected option; escape safely encodes its label as HTML.
        item: function (data, escape) {
          // Selected items show the facet label without the option's result count.
          return '<div>' + escape(data.label || data.$option.dataset.label) + '</div>';
        },
        // Only show a terminal message when browsing was stopped by the page
        // cap; otherwise suppress the plugin's default end-of-results message.
        no_more_results: function (data, escape) {
          return limited ? '<div class="no-more-results">' + escape(element.dataset.pageLimitMessage) + '</div>' : null;
        }
      }
    });
    // Seed the empty query with the first modal page only when the initial
    // server-rendered values indicate more exist; opening the control does not
    // itself issue a request.
    select.setNextUrl('', element.dataset.facetHasMore === 'true' ? select.settings.firstUrl('') : false);
    // A short initial list may not be scrollable, so translate a downward wheel
    // gesture at its bottom into the scroll event consumed by virtual_scroll.
    select.dropdown_content.addEventListener('wheel', function (event) {
      if (event.deltaY > 0 && this.scrollTop + this.clientHeight >= this.scrollHeight - 1) {
        this.dispatchEvent(new Event('scroll'));
      }
    });
    let touchStartY;
    // Remember the start of a touch gesture so an upward swipe on a short list
    // can trigger the same continuation behavior as a downward wheel gesture.
    select.dropdown_content.addEventListener('touchstart', function (event) {
      touchStartY = event.touches[0].clientY;
    }, { passive: true });
    // Trigger a continuation only for an upward swipe at the list's bottom.
    select.dropdown_content.addEventListener('touchmove', function (event) {
      if (event.touches[0].clientY < touchStartY && this.scrollTop + this.clientHeight >= this.scrollHeight - 1) {
        this.dispatchEvent(new Event('scroll'));
      }
    }, { passive: true });
    // Let pointer users activate the loading indicator, rather than treating it
    // as a selectable facet value.
    select.dropdown_content.addEventListener('click', function (event) {
      if (event.target.closest('.loading-more-results')) {
        event.preventDefault();
        event.stopImmediatePropagation();
        this.dispatchEvent(new Event('scroll'));
      }
    }, true);
    // The plugin watches scroll events, so keyboard navigation to its loading
    // indicator must explicitly trigger one to request the next page.
    select.control_input.addEventListener('keyup', function (event) {
      if (event.key === 'ArrowDown' && select.activeOption && select.activeOption.classList.contains('loading-more-results')) {
        select.dropdown_content.dispatchEvent(new Event('scroll'));
      }
    });
    // Prevent callbacks from updating a widget after Turbolinks destroys it.
    select.on('destroy', function () {
      destroyed = true;
      if (activeRequest) activeRequest.abort();
    });
    // Snapshot currently loaded options before retrying: virtual_scroll may
    // otherwise clear previous pages when the request is started directly.
    error.querySelector('.advanced-facet-retry').onclick = function () {
      retryState = { query: select.lastValue, options: Object.values(select.options) };
      select.load(select.lastValue);
    };
    // Tom Select creates its own combobox and list, so label those as well.
    select.focus_node.setAttribute('aria-label', element.getAttribute('aria-label'));
    select.control_input.maxLength = 200;
    select.dropdown_content.setAttribute('aria-label', element.getAttribute('aria-label'));
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
        // Match names like "f[name][]" or "f_inclusive[name][]"
        // f                 Literal "f"
        // (?:_inclusive)?   Optional, non-capturing "_inclusive" suffix
        // \[                Literal opening bracket "["
        // ([^\]]+)          Capture one or more characters other than "]"
        // ]                 Literal closing bracket "]"
        // \[]               Literal "[]"
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
    if (!element.tomselect) return;
    let control = element.tomselect;
    element.parentElement.querySelector('.advanced-facet-load-error').hidden = true;
    // Tom Select restores the original native markup on destroy; record remote
    // selections first so they survive a Turbolinks cache and restoration.
    let selected = control.items.map(function (value) {
      let option = control.options[value];
      return { value: value, text: option.text, label: option.label || option.$option.dataset.label };
    });
    control.destroy();
    // Restore only the current selections, including remotely loaded options
    // that did not exist in the original server-rendered select element.
    Array.from(element.options).forEach(function (option) { option.selected = false; });
    selected.forEach(function (item) {
      let option = Array.from(element.options).find(function (candidate) { return candidate.value === item.value; });
      if (!option) {
        option = new Option(item.text, item.value);
        option.dataset.label = item.label;
        element.add(option);
      }
      option.selected = true;
    });
  });
  document.querySelectorAll('form.advanced').forEach(function (form) {
    delete form.dataset.facetLimitBound;
    let error = form.querySelector('.advanced-search-facet-error');
    if (error) error.hidden = true;
    let valueError = form.querySelector('.advanced-search-facet-value-error');
    if (valueError) valueError.hidden = true;
  });
});
