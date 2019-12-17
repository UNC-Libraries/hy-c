// [hyc-override] Overriding visibility settings
import VisibilityComponent from 'hyrax/save_work/visibility_component'

export default class UncVisibilityComponent extends VisibilityComponent {
    constructor(element, adminWidget) {
        super(element, adminWidget);
    }

    restrictToVisibility(data) {
        // visibility requirement is in HTML5 'data-visibility' attr
        let visibility = data['visibility'];
        // if immediate release required, then 'data-release-no-delay' attr will be true
        let release_no_delay = data['releaseNoDelay'];
        // release date requirement is in HTML5 'data-release-date' attr
        let release_date = data['releaseDate'];
        // if release_date is flexible (i.e. before date), then 'data-release-before-date' attr will be true
        let release_before = data['releaseBeforeDate'];
        let is_admin = this.isAdmin();

        // Restrictions require either a visibility requirement or a date requirement (or both)
        if (is_admin) {
            this.enableAllOptions(false);
        } else if (visibility || release_no_delay || release_date) {
            this.applyRestrictions(visibility, release_no_delay, release_date, release_before);
        } else {
            this.enableAllOptions(false);
        }
    }

    isAdmin() {
        let is_admin = false;

        $('li.h5').each(function() {
            if($(this).text().toLowerCase() === 'configuration') {
                is_admin = true;
                return false;
            }
        });

        return is_admin;
    }

    isNewFile() {
        return /\/new/.test(window.location);
    }

    leastRestrictiveStatus(options) {
        if (options.includes('open')) {
            return ['open'];
        } else if (options.includes('authenticated')) {
            return ['authenticated'];
        } else if (options.includes('embargo')) {
            return ['embargo'];
        } else if (options.includes('restricted')) {
            return ['restricted'];
        } else {
            return ['open'];
        }
    }

    enableAllOptions(isSubmitting = true) {
        this.element.find("[type='radio']").prop("disabled", false);
        this.getEmbargoDateInput().prop("disabled", false);
        this.getVisibilityAfterEmbargoInput().prop("disabled", false);

        // [hyc-override] Override to select "Public" if no restrictions are in place
        if (this.isNewFile() && !isSubmitting) {
            this.element.find("[type='radio'][value='open']").prop('checked', true);
            this.openSelected();
        }
    }

    // Enable one or more visibility option (based on array of passed in options),
    // disabling all other options
    // If embargoes are enabled Hyrax will use this method to determine visibility
    // [hyc-override] Override to gray out disallowed options
    enableVisibilityOptions(options) {
        let matchEnabled = this.getMatcherForVisibilities(this.leastRestrictiveStatus(options));
        let matchDisabled = this.getMatcherForNotVisibilities(options);

        // Enable all that match "matchEnabled" (if any), and disable those matching "matchDisabled"
        if(matchEnabled) {
            let allowed_fields = this.element.find(matchEnabled);
            allowed_fields.prop("disabled", false);

            // Set to allowed visibility if new file
            if (this.isNewFile()) {
                allowed_fields.prop('checked', true);
                this.openSelected();
            }

            allowed_fields.parent().removeClass('hide')
        }
        let disallowed_fields = this.element.find(matchDisabled);
        disallowed_fields.prop("disabled", true);
        disallowed_fields.parent().addClass('hide');
    }

    // Disable one or more visibility option (based on array of passed in options),
    // disabling all other options
    // [hyc-override] Override to gray out embargo option if embargo isn't allowed, but visibility options are set to "Allow All"
    // [hyc-override] Override to select "Public" if embargo isn't allowed, but visibility options are set to "Allow All"
    disableVisibilityOptions(options) {
        let matchDisabled = this.getMatcherForVisibilities(options);
        let matchEnabled = this.getMatcherForNotVisibilities(options);

        // Disable those matching "matchDisabled" (if any), and enable all that match "matchEnabled"
        if(matchDisabled) {
            let disabledField = this.element.find(matchDisabled);
            disabledField.prop("disabled", true);
            disabledField.parent().addClass('hide');
        }
        let enabledField = this.element.find(matchEnabled);
        enabledField.prop("disabled", false);
        enabledField.parent().removeClass('hide');

        if (this.isNewFile()) {
            enabledField.first().prop('checked', true);
            this.openSelected();
        }
    }

    // If embargoes aren't enabled Hyrax will use this method to determine visibility
    // [hyc-override] Override to gray out disallowed options
    selectVisibility(visibility) {
        let allowed_fields = this.element.find("[type='radio'][value='" + visibility + "']");

        // Set to allowed visibility if new file
        if (this.isNewFile()) {
            allowed_fields.prop('checked', true);

            if (visibility === 'open') {
                this.openSelected();
            }
        }

        let allowed_parent = allowed_fields.parent();

        allowed_fields.prop("disabled", false);
        allowed_parent.removeClass('hide');

        let disallowed_fields = this.element.find("[type='radio'][value!='" + visibility + "']");
        let disallowed_parent = disallowed_fields.parent();

        disallowed_fields.prop("disabled", true);
        disallowed_parent.addClass('hide');

        // Ensure required option is opened in form
        this.showForm()
    }
}