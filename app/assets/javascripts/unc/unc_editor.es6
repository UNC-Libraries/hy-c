// [hyc-override] Overriding saveWorkControl to pick up our local changes
import Editor from 'hyrax/editor'
import UncSaveWorkControl from 'unc/unc_save_work_control'

export default class UncEditor extends Editor {
    constructor(element) {
        super(element);
    }

    saveWorkControl() {
        new UncSaveWorkControl(this.element.find("#form-progress"), this.adminSetWidget)
    }
}