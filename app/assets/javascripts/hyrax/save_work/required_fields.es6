// [hyc-override] Override to allow form to be submitted with hidden, empty, cloning fields
// [hyc-override] Override to check for malformed date created and date issued fields
// [hyc-override] Override to block submission when text inputs exceed character limit

const CHARACTER_LIMIT = 10000
const CHARACTER_LIMIT_ALERT_ID = 'character-limit-alert'
export class RequiredFields {
    // Monitors the form and runs the callback if any of the required fields change
    constructor(form, callback) {
        this.form = form
        this.callback = callback
        this.reload()
    }

    get areComplete() {
        let overLimitFields = this.getOverLimitFields()
        this.updateCharacterLimitAlert(overLimitFields)

        return this.requiredFields.filter((n, elem) => { return this.isValuePresent(elem) } ).length === 0
            && overLimitFields.length === 0
    }

    getOverLimitFields() {
        return this.textFields.filter((n, elem) => { return this.isOverCharacterLimit(elem) })
    }

    fieldDisplayName(elem) {
        let selector = $(elem)
        let labelText = ''

        if (elem.id) {
            labelText = this.form.find(`label[for="${elem.id}"]`).first().text()
        }

        if (!labelText) {
            labelText = selector.closest('.form-group').find('label').first().text()
        }

        labelText = (labelText || selector.attr('name') || elem.id || 'Unknown field').replace(/\s+/g, ' ').trim()
        return $('<div>').text(labelText).html()
    }

    updateCharacterLimitAlert(overLimitFields) {
        let existingAlert = this.form.find(`#${CHARACTER_LIMIT_ALERT_ID}`)

        this.textFields.removeClass('is-invalid')
        if (overLimitFields.length === 0) {
            existingAlert.remove()
            return
        }

        overLimitFields.addClass('is-invalid')

        let fieldNames = [...new Set(overLimitFields.toArray().map((elem) => this.fieldDisplayName(elem)))]
        let fieldList = fieldNames.map((name) => `<li>${name}</li>`).join('')
        let alertMarkup = `
            <div id="${CHARACTER_LIMIT_ALERT_ID}" class="alert alert-danger" role="alert" aria-live="assertive">
                <p class="mb-1">Some fields exceed the 10,000 character limit and must be shortened before submitting:</p>
                <ul class="mb-0">${fieldList}</ul>
            </div>
        `

        if (existingAlert.length > 0) {
            existingAlert.replaceWith(alertMarkup)
        } else {
            this.form.prepend(alertMarkup)
        }
    }

    // Keep normalization aligned with TextLengthValidator#normalized_text
    normalizedTextValue(elem) {
        let selector = $(elem)
        let value = selector.val()

        if (typeof tinymce !== 'undefined' && elem.id && tinymce.get(elem.id)) {
            value = tinymce.get(elem.id).getContent()
        }

        if (typeof value !== 'string') return ''

        let text = $('<div>').html(value).text()
        text = text.replace(/\r\n?|\n/g, ' ')
        text = text.replace(/ +/g, ' ')
        return text.trim()
    }

    isOverCharacterLimit(elem) {
        let selector = $(elem)
        let parentHidden = selector.parent().closest('div.cloning')

        if (parentHidden.hasClass('d-none')) {
            return false
        }

        return this.normalizedTextValue(elem).length > CHARACTER_LIMIT
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
        this.textFields = this.form.find('input[type="text"], textarea')
        this.textFields.on('input change', this.callback)
    }
}