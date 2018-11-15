$(document).on('turbolinks:load', function () {
    attach_add_person_listeners('advisor');
    attach_add_person_listeners('arranger');
    attach_add_person_listeners('composer');
    attach_add_person_listeners('funder');
    attach_add_person_listeners('project_director');
    attach_add_person_listeners('researcher');
    attach_add_person_listeners('reviewer');
    attach_add_person_listeners('sponsor');
    attach_add_person_listeners('translator');
});


function attach_add_person_listeners(selector){
    var add_selector = '#add-another-'+selector;
    var remove_selector = '.remove-'+selector;
    var cloning_row = '#'+selector+'-cloning_row';

    $(cloning_row).find('input').each(function() {
        if ($(this).prop('id').match('_id')) {
            $(this).remove();
        }
    });

    remove_row(selector);

    $(add_selector).on('click', function(event){
        // stop page from reloading
        event.preventDefault();

        $(remove_selector).removeClass('hidden');

        var current_index = $('#index-'+selector).val();

        var $new_row = $(cloning_row+' > .row').clone();

        var $name_input = $new_row.find('div.'+selector+'-name input');
        var $orcid_input = $new_row.find('div.'+selector+'-orcid input');
        var $affiliation_input = $new_row.find('div.'+selector+'-affiliation select');
        var $other_affiliation_input = $new_row.find('div.'+selector+'-other-affiliation input');

        var old_name = $name_input.prop('name');
        var old_orcid = $orcid_input.prop('name');
        var old_affiliation = $affiliation_input.prop('name');
        var old_other_affiliation = $other_affiliation_input.prop('name');

        var new_name = old_name.replace(/\d/, current_index);
        var new_orcid = old_orcid.replace(/\d/, current_index);
        var new_affiliation = old_affiliation.replace(/\d/, current_index);
        var new_other_affiliation = old_other_affiliation.replace(/\d/, current_index);

        $name_input.prop('name', new_name);
        $orcid_input.prop('name', new_orcid);
        $affiliation_input.prop('name', new_affiliation);
        $other_affiliation_input.prop('name', new_other_affiliation);

        var old_name_id = $name_input.attr('id');
        var old_orcid_id = $orcid_input.attr('id');
        var old_affiliation_id = $affiliation_input.attr('id');
        var old_other_affiliation_id = $other_affiliation_input.attr('id');

        var new_name_id = old_name_id.replace(/\d/, current_index);
        var new_orcid_id = old_orcid_id.replace(/\d/, current_index);
        var new_affiliation_id = old_affiliation_id.replace(/\d/, current_index);
        var new_other_affiliation_id = old_other_affiliation_id.replace(/\d/, current_index);

        $name_input.attr('id', new_name_id);
        $orcid_input.attr('id', new_orcid_id);
        $affiliation_input.attr('id', new_affiliation_id);
        $other_affiliation_input.attr('id', new_other_affiliation_id);
        
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
        // get current_index again and store it in local variable, decrement it and store it
        var current_index = $('#index-'+selector).val();
        current_index--;

        if (current_index == 1) {
            $('.remove-'+selector).addClass('hidden');
        } else {
            $('.remove-'+selector).removeClass('hidden');
        }

        var name_input = $(cloning_row+' > .row').find('div.'+selector+'-name input').prop('name');
        var model = name_input.split('[')[0];
        var index = $(this).data('index');

        $('#index-'+selector).val(current_index);
        $(this).parents(row_selector).remove();
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
