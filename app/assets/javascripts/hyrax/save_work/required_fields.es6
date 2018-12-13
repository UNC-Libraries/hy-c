// [hyc-override] Override to allow form to be submitted with hidden, empty, cloning fields
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
    isValuePresent(elem) {
        let selector = $(elem);
        let parentHidden = selector.parent().closest('div.cloning');

        if (parentHidden.hasClass('hidden') && parentHidden.hasClass('cloning')) {
            return false;
        }

        let selectorValue = selector.val();
        return (selectorValue === null) || (selectorValue.length < 1);
    }

    // Reassign requiredFields because fields may have been added or removed.
    reload() {
        // ":input" matches all input, select or textarea fields.
        this.requiredFields = this.form.find(':input[required]')
        this.requiredFields.change(this.callback)
    }
}