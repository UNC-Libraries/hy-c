$(document).on('turbolinks:load', function () {
    var PEOPLE_TYPES = ['advisor', 'arranger', 'composer', 'contributor', 'creator',
        'project_director', 'researcher', 'reviewer', 'translator'];
    var PEOPLE_SUBFIELDS = ['name', 'orcid', 'affiliation', 'other_affiliation'];
    
    PEOPLE_TYPES.forEach(function(person) {
        // For each person type present in the form, initialize
        if ($('#' + person).length > 0) {
            // Calculate and store the total number of people of this type
            setPersonTypeIndex(person);
            // Assign indexes to each person row
            assignPersonIndexes(person);
            // Get the cloning row ready for usage
            tidyPersonCloningRow(person);
            // Attach listeners for person modification events
            attachPersonListeners(person);
            // Refresh labels of person entries
            updateAllRows(person);
        }
    });

    function tidyPersonCloningRow(selector) {
        var cloning_row = '#' + selector + '-cloning_row';

        $(cloning_row).find('input').each(function() {
            var $self = $(this);
            if ($self.prop('id').match('_id')) {
                $self.remove();
            }
        });
    }
    
    function attachPersonListeners(person_type) {
        attachAddPersonListener(person_type);
        getPersonRows(person_type).each(function() {
            attachRemovePersonListener(person_type, $(this));
        })
    }

    function attachRemovePersonListener(person_type, $person_row) {
        var remove_selector = '.remove-' + person_type;
        var cloning_row = '#' + person_type + '-cloning_row';

        $person_row.find(remove_selector).on('click', function (event) {
            event.preventDefault();

            // Retrieve the name of the model for this work type
            var name_input = $(cloning_row + ' > .row').find('div.' + person_type + '-name input').prop('name');
            var model = name_input.split('[')[0];
        
            var index = $person_row.data('index');

            $person_row.remove();

            // Trigger a removal event for the overall person object field since the specific instance clicked no longer exists.
            $('#' + person_type).trigger("managed_field:remove");

            // Update row ordering
            updateAllRows(person_type);

            // Record that the person object was removed
            deleteRecord(person_type, model, index);
        });
    }

    function attachAddPersonListener(person_type) {
        var add_selector = '#add-another-' + person_type;
        var remove_selector = '.remove-' + person_type;
        var cloning_row = '#' + person_type + '-cloning_row';
    
        $(add_selector).on('click', function(event) {
            // stop page from reloading
            event.preventDefault();

            $(remove_selector).removeClass('hidden');

            // Retrieve an index for the new person
            var current_index = getNextPersonIndex(person_type);
        
            // Create the new row and assign its index
            var $cloning_row = $(cloning_row + ' > .row');
            var $new_row = $cloning_row.clone();
            $new_row.data('index', current_index);

            // Update inputs and labels for new row fields
            updateLabels($new_row, getLabelNumber(person_type));

            // remove $new_row's id so we don't find it again when looking for blank row to clone
            $new_row.removeAttr('id');
            $new_row.removeClass('hidden');
            $('div#' + person_type).append($new_row);

            attachRemovePersonListener(person_type, $new_row);
            
            // Move the cloning row to the next index
            updateCloningRow($cloning_row, current_index);
        });
    }
    
    function updateCloningRow($cloning_row, current_index) {
        var regex = /\d+/;
        var next_index;

        // Required people seem to have their index updated on page load, Optional people don't, hence the double increment
        if ($cloning_row.find("[id$='name']").hasClass('optional')) {
            next_index = current_index + 2;
        } else {
            next_index = current_index + 1;
        }

        PEOPLE_SUBFIELDS.forEach(function(attr) {
            var $input = $cloning_row.find("[id$='" + attr + "']");

            $input.each(function() {
                var self = $(this);
                self.prop('name', self.prop('name').replace(regex, next_index))
                    .attr('id', self.attr('id').replace(regex, next_index));
            });
        });
    }

    function getNextPersonIndex(personType) {
        var $index_selector = $('#' + personType);
        var current_index = $index_selector.data('current-index');
        // Increment the index for future calls
        $index_selector.data('current-index', current_index + 1);
        return current_index;
    }

    function getPersonRows(selector) {
        return $('#' + selector + ' div.' + selector).not(':hidden');
    }

    function getLabelNumber(selector) {
        return getPersonRows(selector).length;
    }

    function setPersonTypeIndex(selector) {
        var set_value = getLabelNumber(selector);
        $('#' + selector).data('current-index', set_value);
    }

    function assignPersonIndexes(selector) {
        getPersonRows(selector).each(function(index) {
            $(this).data('index', index);
        });
    }

    function deleteRecord(selector, model, index) {
        var delete_id_base = model + '_' + selector + 's_attributes_' + index;
        // Don't need to add a delete record if person entry did not previously exist
        if ($('#' + delete_id_base + '_id').length == 0) {
            return;
        }
        
        // Add delete record to inform server that person removed, unless already present
        var delete_id = delete_id_base + '__destroy';
        if ($('#' + delete_id).length === 0) {
            var delete_input_name = model + '[' + selector + 's_attributes][' + index + '][_destroy]';
            var $new_row = '<input type="hidden" name="' + delete_input_name + '" id="' + delete_id + '" value="1">';
            $('#' + selector).append($new_row);
        }
    }

    function updateAllRows(selector) {
        getPersonRows(selector).each(function(row_index) {
            var self = $(this);
            updateLabels(self, row_index);
        });
    }

    function updateLabels(row, label_index) {
        var regex = /\d+/;
        var index = row.data('index');

        PEOPLE_SUBFIELDS.forEach(function(attr) {
            // Update label
            var $label = row.find("label[for$='" + attr + "']");

            $label.each(function() {
                var self = $(this);
                self.attr('for', self.attr('for').replace(regex, index))
                    .html(self.html().replace(regex, label_index + 1));
            });
        });
    }
});