/**
 * Grouped into functional units for easier grouping of code
 */
$(function() {
    // Check for leading _ plus date, otherwise selects things like "update" too
    var date_field = 'div[class*="_date"] input, input[class*="_date"]';

    // Add datepicker to date fields in forms
    function datePicking() {
        // Remove embargo date field
        var date_inputs = $(date_field).not('input[type=date]');
        var datepicker_options = {
            dateFormat: 'yy-mm-dd',
            beforeShow: function(field) {
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

        // Ensure each date field has a unique id so cloned date fields select the right input
        date_inputs.each(function(index) {
            var self = $(this);
            var current_id = self.attr('id').split(/-\d{1,}$/);
            var updated_id = current_id[0] + '-' + index;

            self.attr('id', updated_id);
            self.removeClass('hasDatepicker');
            $('#' + updated_id).datepicker(datepicker_options);
        });
    }

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

    // Make sure that datepicker works with cloned date fields
    $(document).on('focus', date_field, function() {
        datePicking();
    });

    // Make sure that form visibility and datepicker work with turbolinks
    $(document).on('turbolinks:load', function() {
        datePicking();
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

    // Make file upload div height larger/smaller based on activity
    (function() {
        var progess_bar = $('div.fileupload-progress');

        if (progess_bar.is(':visible')) {
            progess_bar.addClass('progress-bar-active');
        } else {
            progess_bar.removeClass('progress-bar-active');
        }
    }());
});