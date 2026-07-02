// [hyc-override] Override to allow form to be submitted with hidden, empty, cloning fields
// [hyc-override] Override to check for malformed date created and date issued fields
// [hyc-override] Override to check for text/textarea fields exceeding the character limit

const CHARACTER_LIMIT = 10000;
const CHARACTER_LIMIT_MESSAGE = 'One or more fields exceed the 10,000 character limit (whitespace is not counted).';
const CHARACTER_LIMIT_MESSAGE_ID = 'metadata-character-limit-error';

export class RequiredFields {
    // Monitors the form and runs the callback if any of the required fields change
    constructor(form, callback) {
        this.form = form
        this.callback = callback
        this.reload()
    }

    get areComplete() {
        return this.requiredFields.filter((n, elem) => { return this.isValuePresent(elem) } ).length === 0
            && this.areUnderCharacterLimit
    }

    // Returns true when no text/textarea field exceeds the character limit
    get areUnderCharacterLimit() {
        let overLimitFields = this.textFields.filter((n, elem) => { return this.isOverCharacterLimit(elem) });
        this.updateOverLimitFieldStyles(overLimitFields);
        this.toggleCharacterLimitMessage(overLimitFields.length > 0);
        return overLimitFields.length === 0
    }

    // Adds/removes a small inline error in the form-progress metadata requirement row
    toggleCharacterLimitMessage(showMessage) {
        let metadataRequirement = $('#required-metadata');
        if (metadataRequirement.length === 0) return;

        let errorMessage = $('#' + CHARACTER_LIMIT_MESSAGE_ID);

        if (showMessage) {
            if (errorMessage.length === 0) {
                metadataRequirement.append(
                    `<div id="${CHARACTER_LIMIT_MESSAGE_ID}" class="text-danger small mt-1">${CHARACTER_LIMIT_MESSAGE}</div>`
                );
            }
            return;
        }

        errorMessage.remove();
    }

    // Marks fields that exceed the limit to make the validation failure easy to locate
    updateOverLimitFieldStyles(overLimitFields) {
        this.textFields.removeClass('is-invalid');
        overLimitFields.addClass('is-invalid');
    }

    // Returns the visible text value of an element, handling TinyMCE editors
    getFieldValue(elem) {
        if (typeof tinymce !== 'undefined' && elem.id && tinymce.get(elem.id)) {
            return tinymce.get(elem.id).getContent({ format: 'text' });
        }
        let val = $(elem).val();
        if (typeof val !== 'string') return '';
        // Strip any residual HTML tags for non-TinyMCE textareas that may contain markup
        return val.replace(/<[^>]*>/g, '');
    }

    // Returns true if the field's value (whitespace removed) exceeds the character limit
    isOverCharacterLimit(elem) {
        let selector = $(elem);
        // Skip hidden/cloning fields
        let parentHidden = selector.parent().closest('div.cloning');
        if (parentHidden.hasClass('d-none')) return false;

        let value = this.getFieldValue(elem);
        return value.replace(/\s/g, '').length > CHARACTER_LIMIT;
    }

    // Allow form to be submitted with hidden, empty, cloning fields
    // Add check for malformed date created and date issued fields
    isValuePresent(elem) {
        let selector = $(elem);
        let parentHidden = selector.parent().closest('div.cloning');

        if (parentHidden.hasClass('d-none')) {
            return false;
        }

        let selectorValue = selector.val();
        let isSelected = (selectorValue === null) || (selectorValue.length < 1);
        let dateName = selector.prop('name');

        if (/date_issued/.test(dateName)) {
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
        this.requiredFields = this.form.find(':input[required], input[name*="date_issued"]');
        this.requiredFields.change(this.callback)
        // Track all text inputs and textareas for the character limit check
        this.textFields = this.form.find('input[type="text"], textarea');
        this.textFields.on('change input', this.callback)
    }
}