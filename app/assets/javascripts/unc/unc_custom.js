/**
 * Grouped into functional units for easier grouping of code
 */
$(function() {
    // Only show student paper options in modal when clicking "Student Papers" link on homepage
    function visibleForms() {
        var all_work_types = $('form.new-work-select .select-worktype');

        // Remove any currently hidden student work types
        $('.all-unc-work-types').on('click', function() {
            all_work_types.removeClass('hidden');
        });

        // Filter form options based on which button is clicked
        // Filters "Student Papers" and "Other Deposits" options
        $('#unc-deposit').on('click', function(e) {
            var clicked_link = e.target.parentNode.id;
            var negated = false;
            var regex;

            if (clicked_link === 'student-papers-work-types') {
                regex = /MastersPaper|HonorsThesis/;
                negated = true;
            } else if (clicked_link === 'other-deposit-work-types') {
                regex = /MastersPaper|HonorsThesis|Article|DataSet/;
            } else {
                return;
            }

            all_work_types.filter(function(index, element) {
                var work_type = $(this).find('input[type=radio]').attr('value');

                if (negated) {
                    return !regex.test(work_type);
                } else {
                    return regex.test(work_type);
                }
            }).addClass('hidden');
        });
    }

    function browseEverythingUploads() {
        $('#browse-btn').browseEverything({
            route: "/browse",
            target: "#" + $('form').attr('id')
        });
    }
  
    // Make file upload div height larger/smaller based on activity
    function uploadProgress() {
        var progess_bar = $('div.fileupload-progress');

        if (progess_bar.is(':visible')) {
            progess_bar.addClass('progress-bar-active');
        } else {
            progess_bar.removeClass('progress-bar-active');
        }
    }

    function hideNonRequiredFieldsBtn() {
        $('#metadata a.additional-fields').on('click', function () {
            $(this).addClass('hidden');
        });
    }

    function hideNonRequiredFormFields() {
        // Remove class to hide non-required fields
        // Isn't there by default so fields still show if JS is turned off
        $('#extended-terms').removeClass('in').attr('aria-expanded', false);

        // Set to false if JS is turned on
        $('a.additional-fields').attr('aria-expanded', false);
    }

    // Remove hidden, cloning people elements. They prevent forms from submitting as they have required fields
    function removeCloning() {
        $('#with_files_submit').on('click touchstart', function() {
            $('div.cloning').remove();
        });
    }

    visibleForms();
    browseEverythingUploads();
    uploadProgress();
    hideNonRequiredFieldsBtn();
    hideNonRequiredFormFields();
    removeCloning();

    // Make sure that form visibility and datepicker work with turbolinks
    $(document).on('turbolinks:load', function() {
        visibleForms();
        browseEverythingUploads();
        uploadProgress();
        hideNonRequiredFieldsBtn();
        hideNonRequiredFormFields();
        removeCloning();
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