$(document).ready(function () {
    attach_add_committee_listeners('advisor');
});


function attach_add_committee_listeners(selector){
    var add_selector = '#add-another-'+selector;
    var row_selector = '.'+selector+'.row';
    var remove_selector = '.remove-'+selector;
    var cloning_row = '#'+selector+'-cloning_row';

    $(row_selector).first().on('click', function(){
        // get current_index again and store it in local variable, decrement it and store it
        var current_index = $('#index-'+selector).val();
        current_index--;

        $('#index-'+selector).val(current_index);
        $(this).parents(this).remove();
    });

    $(add_selector).on('click', function(event){
        $('.remove-'+selector).removeClass('hidden');

        var current_index = $('#index-'+selector).val();

        var $new_row = $(cloning_row+' > .row').clone();

        var $name_input = $new_row.find('div.'+selector+'-name input');
        var $orcid_input = $new_row.find('div.'+selector+'-orcid input');
        var $affiliation_input = $new_row.find('div.'+selector+'-affiliation input');
        var $other_affiliation_input = $new_row.find('div.'+selector+'-other-affiliation input');

        var old_name = $name_input.prop('name');
        var old_orcid = $name_input.prop('name');
        var old_affiliation = $name_input.prop('name');
        var old_other_affiliation = $name_input.prop('name');

        var new_name = old_name.replace(/\d/, current_index);
        var new_orcid = old_orcid.replace(/\d/, current_index);
        var new_affiliation = old_affiliation.replace(/\d/, current_index);
        var new_other_affiliation = old_other_affiliation.replace(/\d/, current_index);

        $name_input.prop('name', new_name);
        $orcid_input.prop('name', new_orcid);
        $affiliation_input.prop('name', new_affiliation);
        $other_affiliation_input.prop('name', new_other_affiliation);

        //change $new_row's id so we don't find it again when looking for blank row to clone
        $new_row.prop('id', 'cloned_'+selector+'_row');

        var $removeMember = $new_row.find(remove_selector);

        $new_row.removeClass('hidden');
        $('div#'+selector).append($new_row);

        current_index++;
        $('#index-'+selector).val(current_index);

        $removeMember.on('click', function(){
            // get current_index again and store it in local variable, decrement it and store it
            var current_index = $('#index-'+selector).val();
            current_index--;

            $('#index-'+selector).val(current_index);
            $(this).parents(row_selector).remove();
        });
    });
}
