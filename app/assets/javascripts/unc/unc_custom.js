/**
 * Grouped into functional units for easier grouping of code
 */
$(function() {
    // Only show student paper options in modal when clicking "Student Papers" link on homepage
    function visibleForms() {
        var all_work_types = $('form.new-work-select .select-worktype');

        // Remove any currently hidden student work types
        $('.all-unc-work-types').on('click', function() {
            all_work_types.removeClass('d-none');
        });

        // Filter form options based on which button is clicked
        // Filters "Student Papers" and "Other Deposits" options
        $('#unc-deposit').on('click', function(e) {
            var clicked_link = e.target.parentNode.id;
            var negated = false;
            var regex;

            // Clear all hidden forms before hiding current clicked options
            all_work_types.removeClass('d-none');

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
            }).addClass('d-none');
        });
    }

    /*function browseEverythingUploads() {
        $('#browse-btn').browseEverything({
            route: "/browse",
            target: "#" + $('form').attr('id')
        });
    }*/

    // Set page link for accessible version request
    function accessUrl() {
        // current page without # or ? parameters
        var current_page = encodeURI(location.protocol + '//' + location.host + location.pathname);
        var access_link = $('.access-request');
        var current_link = access_link.attr('href');
        access_link.attr('href', current_link + '?current_page=' + current_page);
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
            $(this).addClass('d-none');
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

    function toggleCollectionPageDescription() {
        var full_text = $('.full');
        var less_text = $('.truncated');

        $('#collection-description-text-btn').on('click touchstart', function() {
            var show_less_text = less_text.hasClass('d-none');
            var btn_text = (show_less_text) ? 'Show More' : 'Show Less';

            if (show_less_text) {
                full_text.addClass('d-none');
                less_text.removeClass('d-none');
            } else {
                full_text.removeClass('d-none');
                less_text.addClass('d-none');
            }

            $(this).text(btn_text);
        });
    }

    // based_near is the only controlled field we use
    // If we add more this function will need to be revised
    function showRemoveOption() {
        var base_selector = 'div.controlled_vocabulary';
        var based_near_remove = $(base_selector +' span.field-controls');

        // Hide on new record page load
        based_near_remove.each(function() {
            var self = $(this);
            if (!self.parent().children().first().hasClass('select2-container-disabled')) {
                self.addClass('hide');
            }
        });

        // Show/hide otherwise
        $(base_selector).on('click', function () {
            // Get new set of fields since there have been additions/deletions
            var controlled_fields = $(base_selector + ' span.field-controls');

            if ($(base_selector + ' .listing li.input-append').filter(':visible').length > 1) {
                controlled_fields.addClass('hide');
            }

            $(base_selector + ' .listing li.input-append input').each(function() {
                var self = $(this);
                if (self.prop('readonly')) {
                    self.parent().children().removeClass('hide');
                }
            });
        });
    }

    // Local modifications to the editor's visibility component behaviors
    function modifyVisibilityComponent() {
        var visibility = $('.visibility');
        if (visibility.length == 0) {
            return;
        }

        let is_admin = isAdmin();
        if (is_admin) {
            // Enable all visibility options for admins
            visibility.find("*:disabled").prop("disabled", false);
        } else {
            // hide disabled visibility options
            visibility.find('.form-check-input:disabled').parentsUntil(visibility, '.form-check').addClass('d-none');
        }
        // If this is a new work, then default to the first active visibility option
        if (isNewFile(visibility)) {
            visibility.find('.form-check-input:not([disabled]):first').click();
        }
    }

    function isNewFile(component) {
        return component.parents('.simple_form').first().attr('id').startsWith('new_');
    }

    function isAdmin() {
        return $('li.h5:contains("Configuration")').length > 0;
    }

    visibleForms();
    modifyVisibilityComponent();
   // browseEverythingUploads();
    accessUrl()
    uploadProgress();
    hideNonRequiredFieldsBtn();
    hideNonRequiredFormFields();
    removeCloning();
    toggleCollectionPageDescription();
    showRemoveOption();

    // Make sure that form visibility and datepicker work with turbolinks
    $(document).on('turbolinks:load', function() {
        visibleForms();
        modifyVisibilityComponent();
     //   browseEverythingUploads();
        uploadProgress();
        hideNonRequiredFieldsBtn();
        hideNonRequiredFormFields();
        removeCloning();
        toggleCollectionPageDescription();
        showRemoveOption();

        // Turns advanced search multi-select boxes into typeaheads
        $(".advanced-search-facet-select").chosen({ placeholder_text: 'Select option(s)'});
    });
});