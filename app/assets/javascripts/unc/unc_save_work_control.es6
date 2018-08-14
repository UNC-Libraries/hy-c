import SaveWorkControl from 'hyrax/save_work/save_work_control'
import { RequiredFields } from 'hyrax/save_work/required_fields'
import { ChecklistItem } from 'hyrax/save_work/checklist_item'
import { UploadedFiles } from 'hyrax/save_work/uploaded_files'
import { DepositAgreement } from 'hyrax/save_work/deposit_agreement'
import UncVisibilityComponent from 'unc/unc_visibility_component'

export default class UncSaveWorkControl extends SaveWorkControl {
    constructor(element, adminSetWidget) {
        super(element, adminSetWidget);
    }

    // Override to call UNC visibilityComponent
    activate() {
        if (!this.form) {
            return
        }
        this.requiredFields = new RequiredFields(this.form, () => this.formStateChanged());
        this.uploads = new UploadedFiles(this.form, () => this.formStateChanged());
        this.saveButton = this.element.find(':submit');
        this.depositAgreement = new DepositAgreement(this.form, () => this.formStateChanged());
        this.requiredMetadata = new ChecklistItem(this.element.find('#required-metadata'));
        this.requiredFiles = new ChecklistItem(this.element.find('#required-files'));
        this.requiredAgreement = new ChecklistItem(this.element.find('#required-agreement'));
        new UncVisibilityComponent(this.element.find('.visibility'), this.adminSetWidget);
        this.preventSubmit();
        this.watchMultivaluedFields();
        this.formChanged();
        this.addFileUploadEventListeners();
    }

    addFileUploadEventListeners() {
        let $uploadsEl = this.uploads.element;
        const $cancelBtn = this.uploads.form.find('#file-upload-cancel-btn');

        $uploadsEl.bind('fileuploadstart', () => {
            $cancelBtn.removeClass('hidden');
        });

        $uploadsEl.bind('fileuploadstop', () => {
            $cancelBtn.addClass('hidden');
        });
    }
}