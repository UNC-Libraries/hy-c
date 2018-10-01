/**
 * Grouped into functional units for easier grouping of code
 */
$(function() {
    // Only show student paper options in modal when clicking "Student Papers" link on homepage
    function visibleForms() {
        var all_work_types = $('form.new-work-select .select-worktype');

        $('#student-papers-work-types').on('click', function() {
            all_work_types.filter(function(index, element) {
                var work_type = $(this).find('input[type=radio]').attr('value');
                return !/MastersPaper|HonorsThesis/.test(work_type);
            }).addClass('hidden');
        });

        // Make sure all forms are visible when non student papers deposits links are clicked
        $('.all-unc-work-types').on('click', function() {
            all_work_types.removeClass('hidden');
        });
    }

    visibleForms();

    // Make sure that form visibility and datepicker work with turbolinks
    $(document).on('turbolinks:load', function() {
        visibleForms();
    });

    // Override default workEditor to pick up our local changes
    Hyrax.workEditor = function() {
        var element = $("[data-behavior='work-form']")
        if (element.length > 0) {
            var Editor = require('unc/unc_editor');
            new Editor(element).init();
        }
    };

});