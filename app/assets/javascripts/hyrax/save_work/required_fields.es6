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

        if (/date_created/.test(selector.prop('name')) || /date_issued/.test(selector.prop('name'))) {
            // ([Jj]an(uary)?|[Ff]eb(ruary)?|[Mm]ar(ch)?|[Aa]pr(il)?|[Mm]ay|[Jj]une|[Jj]uly|[Aa]ug(ust)?|[Ss]ept(ember)?|[Oo]ct(ober)?|[Nn]ov(ember)?|[Dd]ec(ember)?|[Cc]irca|[Ss]pring|[Ss]ummer|[Ff]all|[Ww]inter|[Aa]utumn)?\s{0,}\d{4}s? matches Spring 2000, July 2000, 2000, 2000s, circa 2000
            // \d{4}(\\|\/|-)\d{2}(\\|\/|-)\d{2} matches 2000-01-01, 2000/01/01, 2000\01\01
            // \d{2}(\\|\/|-)\d{2}(\\|\/|-)\d{4} matches 01-01-2000, 01/01/2000, 01\01\2000
            // \d{4}\s{0,}to\s{0,}\d{4} matches 2000 to 2010
            // ([Jj]an(uary)?|[Ff]eb(ruary)?|[Mm]ar(ch)?|[Aa]pr(il)?|[Mm]ay|[Jj]une|[Jj]uly|[Aa]ug(ust)?|[Ss]ept(ember)?|[Oo]ct(ober)?|[Nn]ov(ember)?|[Dd]ec(ember))\s+\d{1,2}[a-zA-Z]{0,2},?\s{0,}\d{4} matches July 1st 2000, July 1st, 2000, July 1 2000, July 1, 2000
            // [Uu]nknown) matches Unknown, unknown
            // ^$ matches empty string
            let regex = [
                '^(([Jj]an(uary)?|[Ff]eb(ruary)?|[Mm]ar(ch)?|[Aa]pr(il)?|[Mm]ay|[Jj]une|[Jj]uly|[Aa]ug(ust)?|[Ss]ept(ember)?|[Oo]ct(ober)?|[Nn]ov(ember)?|[Dd]ec(ember)?|[Cc]irca|[Ss]pring|[Ss]ummer|[Ff]all|[Ww]inter|[Aa]utumn)?\\s{0,}\\d{4}s?',
                '\\d{4}(\\\\|\\/|-)\\d{2}(\\\\|\\/|-)\\d{2}',
                '\\d{2}(\\\\|\\/|-)\\d{2}(\\\\|\\/|-)\\d{4}',
                '\\d{4}\\s{0,}to\\s{0,}\\d{4}',
                '([Jj]an(uary)?|[Ff]eb(ruary)?|[Mm]ar(ch)?|[Aa]pr(il)?|[Mm]ay|[Jj]une|[Jj]uly|[Aa]ug(ust)?|[Ss]ept(ember)?|[Oo]ct(ober)?|[Nn]ov(ember)?|[Dd]ec(ember))\\s+\\d{1,2}[a-zA-Z]{0,2},?\\s{0,}\\d{4}',
                '[Uu]nknown|^$)$'
            ].join('|');

            let dateRegex = new RegExp(regex);

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