$(document).on('turbolinks:load', function () {
    var people = ['advisor', 'arranger', 'composer', 'contributor', 'creator', 'project_director', 'researcher',
        'reviewer', 'translator'];
    people.forEach(function(person) {
        attach_add_person_listeners(person);
        updateAllRows('.'+ person + '.row');
    });
});

function attach_add_person_listeners(selector){
    var add_selector = '#add-another-'+selector;
    var remove_selector = '.remove-'+selector;
    var cloning_row = '#'+selector+'-cloning_row';

    $(cloning_row).find('input').each(function() {
        var $self = $(this);
        if ($self.prop('id').match('_id')) {
            $self.remove();
        }
    });

    $(add_selector).on('click', function(event){
        // stop page from reloading
        event.preventDefault();

        $(remove_selector).removeClass('hidden');

        var index_selector = $('#index-'+selector);
        var current_index = index_selector.val();
        var $new_row = $(cloning_row+' > .row').clone();

        // Update inputs and labels for new row fields
        updateFields($new_row , current_index);

        //change $new_row's id so we don't find it again when looking for blank row to clone
        $new_row.prop('id', 'cloned_'+selector+'_row');

        var $removeMember = $new_row.find(remove_selector);
        $($removeMember).data('index', current_index);

        $new_row.removeClass('hidden');
        $('div#'+selector).append($new_row);

        current_index++;
        index_selector.val(current_index);

        remove_row(selector, parseInt(current_index));
    });
}

function remove_row(selector, current_index) {
    var row_selector = '.'+selector+'.row';
    var remove_selector = '.remove-'+selector;

    $(remove_selector).on('click', function (event) {
        event.preventDefault();

        var $self = $(this);
        $self.parents(row_selector).remove();

        // Trigger a removal event for the overall person object field since the specific instance clicked no longer exists.
        $('#'+selector).trigger("managed_field:remove");

        current_index--;
        $('#index-'+selector).val(current_index);

        // Update row ordering
        updateAllRows(row_selector)
    });
}

function updateAllRows(row_selector) {
    $(row_selector).not(':hidden').each(function(row_index) {
        var self = $(this);
        updateFields(self, row_index);
    });
}

function updateFields(row, current_index) {
    ['name', 'orcid', 'affiliation', 'other_affiliation'].forEach(function(field) {
        updateRow(row, field, current_index);
    });
}

function updateRow(new_row, attr, index) {
    var regex = /\d+/;

    // Update input
    var $input = new_row.find("[id$='" + attr + "']");
    
    $input.each(function() {
        var self = $(this);
        self.prop('name', self.prop('name').replace(regex, index))
            .attr('id', self.attr('id').replace(regex, index));
    });
    
    // Update label
    var $label = new_row.find("label[for$='" + attr + "']");

    $label.each(function() {
        var self = $(this);
        self.attr('for', self.attr('for').replace(regex, index))
            .html(self.html().replace(regex, parseInt(index) + 1));
    });
}
