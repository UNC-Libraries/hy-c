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


        // Remove any currently hidden student work types
        $('.all-unc-work-types').on('click', function() {
            all_work_types.removeClass('hidden');

            all_work_types.filter(function(index, element) {
                var work_type = $(this).find('input[type=radio]').attr('value');
                return /ArtMfa/.test(work_type);
            }).addClass('hidden');
        });
    }

    function browseEverythingUploads() {
        $('#browse-btn').browseEverything({
            route: "/browse",
            target: "#" + $('form').attr('id')
        });
    }

    visibleForms();
    browseEverythingUploads();

    // Make sure that form visibility and datepicker work with turbolinks
    $(document).on('turbolinks:load', function() {
        visibleForms();
        browseEverythingUploads();
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

    (function hideNonRequiredFormFields() {
        // Remove class to hide non-required fields
        // Isn't there by default so fields still show if JS is turned off
        $('#extended-terms').removeClass('in').attr('aria-expanded', false);

        // Set to false if JS is turned on
        $('a.additional-fields').attr('aria-expanded', false);
    }());
});