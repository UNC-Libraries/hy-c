$(document).on('turbolinks:load', function () {
    var people = ['advisor', 'arranger', 'composer', 'contributor', 'creator', 'project_director', 'researcher',
        'reviewer', 'translator'];
    $(people).each(function(index, person) {
        attach_add_person_listeners(person);
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

    remove_row(selector);

    $(add_selector).on('click', function(event){
        // stop page from reloading
        event.preventDefault();

        $(remove_selector).removeClass('hidden');

        var current_index = $('#index-'+selector).val();

        var $new_row = $(cloning_row+' > .row').clone();

        updateNewRow($new_row, selector, 'name', current_index);
        updateNewRow($new_row, selector, 'orcid', current_index);
        updateNewRow($new_row, selector, 'affiliation', current_index);
        updateNewRow($new_row, selector, 'other-affiliation', current_index);

        //change $new_row's id so we don't find it again when looking for blank row to clone
        $new_row.prop('id', 'cloned_'+selector+'_row');

        var $removeMember = $new_row.find(remove_selector);
        $($removeMember).data('index', current_index);

        $new_row.removeClass('hidden');
        $('div#'+selector).append($new_row);

        current_index++;
        $('#index-'+selector).val(current_index);

        remove_row(selector);
    });
}

function remove_row(selector) {
    var row_selector = '.'+selector+'.row';
    var remove_selector = '.remove-'+selector;
    var cloning_row = '#'+selector+'-cloning_row';

    $(remove_selector).on('click', function (event) {
        event.preventDefault();

        var $self = $(this);

        // get current count and store it in local variable
        var count = $(row_selector+':visible').length;
        count--;

        if (count == 1) {
            $(remove_selector).addClass('hidden');
        } else {
            $(remove_selector).removeClass('hidden');
        }

        var name_input = $(cloning_row+' > .row').find('div.'+selector+'-name input').prop('name');
        var model = name_input.split('[')[0];
        var index = $self.data('index');

        $self.parents(row_selector).remove();
        if ($('#'+model+ '_'+selector+'s_attributes_'+index+'_id').length) {
            delete_record(selector, model, index);
        }
    });
}

function delete_record(selector, model, index) {
    var $new_row = '<input type="hidden" name="'+model+'['+selector+'s_attributes]['+index+'][_destroy]" id="'+model+
        '_'+selector+'s_attributes_'+index+'__destroy" value="1">';
    $('div#'+selector).append($new_row);
}

function updateNewRow(new_row, selector, attr, index) {
    var model = $(new_row).find('div.'+selector+'-name input').prop('name').split('[')[0];
    var $input = $(new_row).find('div.'+selector+'-'+attr+' > '+model+'_'+selector+'s_'+attr+' > input,select');
    $input.prop('name', $input.prop('name').replace(/\d/, index));
    $input.attr('id', $input.attr('id').replace(/\d/, index));
}
