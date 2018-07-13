$(function() {
    // Add datepicker to date fields in forms
    $('input[id*="date"]').datepicker({
        maxDate: '+0D',
        dateFormat: 'yy-mm-dd'
    });


    // Only show student paper options in modal when clicking "Student Papers" link on homepage
    var all_work_types = $('form.new-work-select .select-worktype');

    $('#student-papers-work-types').on('click', function (d) {
        all_work_types.filter(function(index, element) {
            var work_type = $(this).find('input[type=radio]').attr('value');
            return !/MastersPaper|HonorsThesis/.test(work_type);
        }).addClass('hidden');
    });

    // Make sure all forms ar visible when non student papers deposits links are clicked
    $('.all-unc-work-types').on('click', function(d) {
       all_work_types.removeClass('hidden');
    });
});