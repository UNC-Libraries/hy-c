/**
 * Grouped into functional units for easier grouping of code
 * Each function is self executing
 */
$(function() {
    // Add datepicker to date fields in forms
    (function datePicking() {
        var datepicker_options = {
            dateFormat: 'yy-mm-dd',
            beforeShow:function(field) {
                // Make sure datepicker is always top element
                $(field).css({
                    'position': 'relative',
                    'z-index': 100
                });
            }
        };

        // Allow future dates for embargoes
        if ($('#file_set_embargo_release_date').length > 0) {
            datepicker_options['maxDate'] = null;
        } else {
            datepicker_options['maxDate'] = '+0D';
        }

        // Check for leading _ plus date, otherwise selects things like "update" too
        $('input[id*="_date"]').datepicker(datepicker_options);
    })();


    // Only show student paper options in modal when clicking "Student Papers" link on homepage
    (function visibleForms() {
        var all_work_types = $('form.new-work-select .select-worktype');

        $('#student-papers-work-types').on('click', function () {
            all_work_types.filter(function(index, element) {
                var work_type = $(this).find('input[type=radio]').attr('value');
                return !/MastersPaper|HonorsThesis/.test(work_type);
            }).addClass('hidden');
        });

        // Make sure all forms ar visible when non student papers deposits links are clicked
        $('.all-unc-work-types').on('click', function() {
            all_work_types.removeClass('hidden');
        });
    })();
});