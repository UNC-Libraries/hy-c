$(document).on('turbolinks:load', function () {
    ['advisor', 'arranger', 'composer', 'contributor', 'creator', 'project_director', 'researcher',
        'reviewer', 'translator'].forEach(function(person) {
        setPersonIndex(person);
        attachAddPersonListeners(person);
        updateAllRows('.'+ person + '.row', getLabelNumber(person));
    });
});

function attachAddPersonListeners(selector) {
    var add_selector = '#add-another-'+selector;
    var remove_selector = '.remove-'+selector;
    var cloning_row = '#'+selector+'-cloning_row';

    $(cloning_row).find('input').each(function() {
        var $self = $(this);
        if ($self.prop('id').match('_id')) {
            $self.remove();
        }
    });

    removeRow(selector);

    $(add_selector).on('click', function(event) {
        // stop page from reloading
        event.preventDefault();

        $(remove_selector).removeClass('hidden');

        var index_selector = $('#' + selector);
        var current_index = index_selector.attr('data-' + selector);
        var $new_row = $(cloning_row + ' > .row').clone();

        // Update inputs and labels for new row fields
        var regex = /\d+/;

        ['name', 'orcid', 'affiliation', 'other_affiliation'].forEach(function(attr) {
            var $input = $new_row.find("[id$='" + attr + "']");

            $input.each(function() {
                var self = $(this);
                self.prop('name', self.prop('name').replace(regex, current_index))
                    .attr('id', self.attr('id').replace(regex, current_index));
            });
        });

        updateLabels($new_row , current_index, getLabelNumber(selector));

        //change $new_row's id so we don't find it again when looking for blank row to clone
        $new_row.prop('id', 'cloned_' + selector + '_row');

        var $removeMember = $new_row.find(remove_selector);
        $($removeMember).data('index', current_index);

        $new_row.removeClass('hidden');
        $('div#' + selector).append($new_row);

        setPersonIndex(selector);

        removeRow(selector);
    });
}

function removeRow(selector) {
    var row_selector = '.' + selector + '.row';
    var remove_selector = '.remove-' + selector;
    var cloning_row = '#' + selector + '-cloning_row';

    $(remove_selector).on('click', function (event) {
        event.preventDefault();

        var $self = $(this);
        var name_input = $(cloning_row + ' > .row').find('div.' + selector + '-name input').prop('name');
        var model = name_input.split('[')[0];
        var index = $self.data('index');

        $self.parents(row_selector).remove();

        // Trigger a removal event for the overall person object field since the specific instance clicked no longer exists.
        $('#' + selector).trigger("managed_field:remove");

        // Update row ordering
        updateAllRows(row_selector, getLabelNumber(selector));

        if ($('#' + model + '_' + selector + 's_attributes_' + index + '_id').length) {
            deleteRecord(selector, model, index);
        }
    });
}

function getLabelNumber(selector) {
    return $('#' + selector + ' div.' + selector).not(':hidden').length;
}

function setPersonIndex(selector) {
    var data_index = $('#' + selector);

    if (data_index.length > 0) {
        var current_index = data_index.data(selector);
        var set_value = (current_index > 0) ? current_index : getLabelNumber(selector);

        data_index.attr('data-' + selector, set_value);
    }
}

function deleteRecord(selector, model, index) {
    var select_string = model + '_' + selector + 's_attributes_'+ index +'__destroy';

    if ($('#' + select_string).length === 0) {
        var $new_row = '<input type="hidden" name="' + model + '[' + selector + 's_attributes][' + index +' ' +
            '][_destroy]" id="' + select_string + '" value="1">';
        $('div#' + selector).append($new_row);
    }
}

function updateAllRows(row_selector, label_index) {
    $(row_selector).not(':hidden').each(function(row_index) {
        var self = $(this);
        var offset = label_index - row_index;
        updateLabels(self, row_index, label_index - offset);
    });
}

function updateLabels(row, index, label_index) {
    var regex = /\d+/;

    ['name', 'orcid', 'affiliation', 'other_affiliation'].forEach(function(attr) {
        // Update label
        var $label = row.find("label[for$='" + attr + "']");

        $label.each(function() {
            var self = $(this);
            self.attr('for', self.attr('for').replace(regex, index))
                .html(self.html().replace(regex, label_index + 1));
        });
    });
}