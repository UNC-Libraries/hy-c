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
            this.enableAllOptions();
        } else if (visibility || release_no_delay || release_date) {
            this.applyRestrictions(visibility, release_no_delay, release_date, release_before);
        } else {
            this.enableAllOptions();
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

    // Enable one or more visibility option (based on array of passed in options),
    // disabling all other options
    // If embargoes are enabled Hyrax will use this method to determine visibility
    enableVisibilityOptions(options) {
        let matchEnabled = this.getMatcherForVisibilities(options)
        let matchDisabled = this.getMatcherForNotVisibilities(options)

        // Enable all that match "matchEnabled" (if any), and disable those matching "matchDisabled"
        if(matchEnabled) {
            let allowed_fields = this.element.find(matchEnabled);
            allowed_fields.prop("disabled", false);
            allowed_fields.removeClass('highlight-disabled')
        }
        let disallowed__fields = this.element.find(matchDisabled);
        disallowed__fields.prop("disabled", true);
        disallowed__fields.parent().addClass('highlight-disabled');
    }

    // If embargoes aren't enabled Hyrax will use this method to determine visibility
    selectVisibility(visibility) {
        let allowed_fields = this.element.find("[type='radio'][value='" + visibility + "']");
        let allowed_parent = allowed_fields.parent();

        allowed_fields.prop("disabled", false);
        allowed_parent.removeClass('highlight-disabled');

        let disallowed_fields = this.element.find("[type='radio'][value!='" + visibility + "']");
        let disallowed_parent = disallowed_fields.parent();

        disallowed_fields.prop("disabled", true);
        disallowed_parent.addClass('highlight-disabled');

        // Ensure required option is opened in form
        this.showForm()
    }
}