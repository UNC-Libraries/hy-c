// [hyc-override] Override to allow form to be submitted with hidden, empty, cloning fields
// [hyc-override] Override to check for malformed date created and date issued fields
export class RequiredFields {
    // Monitors the form and runs the callback if any of the required fields change
    constructor(form, callback) {
        this.form = form
        this.callback = callback
        this.reload()
    }

    get areComplete() {
        return this.requiredFields.filter((n, elem) => { return this.isValuePresent(elem) } ).length === 0
    }

    // Allow form to be submitted with hidden, empty, cloning fields
    // Add check for malformed date created and date issued fields
    isValuePresent(elem) {
        let selector = $(elem);
        let parentHidden = selector.parent().closest('div.cloning');

        if (parentHidden.hasClass('hidden')) {
            return false;
        }

        let selectorValue = selector.val();
        let isSelected = (selectorValue === null) || (selectorValue.length < 1);
        let dateName = selector.prop('name');

        if (/date_created/.test(dateName) || /date_issued/.test(dateName)) {
            let regex = [
                // matches Spring 2000, Aug 2000, July 2000, 2000, 2000s, circa 2000
                '^((jan(uary)?|feb(ruary)?|mar(ch)?|apr(il)?|may|june|july|aug(ust)?|sept(ember)?|oct(ober)?|nov(ember)?|dec(ember)?|circa|spring|summer|fall|winter|autumn)?\\s*\\d{4}s?',
                // matches 2000-01-01
                '\\d{4}-\\d{2}-\\d{2}',
                // matches 01-01-2000, 01/01/2000
                '\\d{2}(\/|-)\\d{2}(\/|-)\\d{4}',
                // matches 2000 to 2010, 2000-2010
                '\\d{4}(\\s*to\\s*|-)\\d{4}',
                // matches July 1st 2000, July 1st, 2000, July 1 2000, July 1, 2000
                '(jan(uary)?|feb(ruary)?|mar(ch)?|apr(il)?|may|june|july|aug(ust)?|sept(ember)?|oct(ober)?|nov(ember)?|dec(ember)?)\\s+\\d{1,2}(st|nd|rd|th)?,?\\s*\\d{4}',
                // matches Unknown, unknown and empty string
                'unknown|^$)$'
            ].join('|');

            let dateRegex = new RegExp(regex, 'i');

            if (selector.hasClass('required')) {
                return (!dateRegex.test(selectorValue) || isSelected);
            } else {
                return !dateRegex.test(selectorValue);
            }
        }

        return isSelected;
    }

    // Reassign requiredFields because fields may have been added or removed.
    reload() {
        // ":input" matches all input, select or textarea fields.
        this.requiredFields = this.form.find(':input[required], input[name*="date_created"], input[name*="date_issued"]');
        this.requiredFields.change(this.callback)
    }
}