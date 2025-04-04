// [hyc-override] https://github.com/samvera/hydra-editor/blob/v6.2.0/app/assets/javascripts/hydra-editor/field_manager.es6
export class FieldManager {
    constructor(element, options) {
        this.element = $(element);

        this.options = options;

        this.options.label = this.getFieldLabel(this.element, options)

        this.addSelector = '.add'
        this.removeSelector = '.remove'

        this.adder    = this.createAddHtml(this.options)
        this.remover  = this.createRemoveHtml(this.options)

        this.controls = $(options.controlsHtml);

        this.inputTypeClass = options.inputTypeClass;
        this.fieldWrapperClass = options.fieldWrapperClass;
        this.warningClass = options.warningClass;
        this.listClass = options.listClass;
        // [hyc-override] - Capture TinyMCE configuration
        this.tinyMCEConfig = TinyMCERails.configuration.rich_text;

        this.init();
    }

    init() {
        this._addInitialClasses();
        this._addAriaLiveRegions()
        this._appendControls();
        this._attachEvents();
        this._addCallbacks();
    }

    _addInitialClasses() {
        this.element.addClass("managed");
        $(this.fieldWrapperClass, this.element).addClass("input-group input-append");
    }

    _addAriaLiveRegions() {
        $(this.element).find('.listing').attr('aria-live', 'polite')
    }

    // Add the "Add another" and "Remove" controls to the DOM
    _appendControls() {
        // We want to make these DOM additions idempotently, so exit if it's
        // already set up.
        if (!this._hasRemoveControl()) {
            this._createRemoveWrapper()
            this._createRemoveControl()
        }

        if (!this._hasAddControl()) {
            this._createAddControl()
        }
    }

    _createRemoveWrapper() {
        $(this.fieldWrapperClass, this.element).append(this.controls);
    }

    _createRemoveControl() {
        $(this.fieldWrapperClass + ' .field-controls', this.element).append(this.remover)
    }

    _createAddControl() {
        this.element.find(this.listClass).after(this.adder)
    }

    _hasRemoveControl() {
        return this.element.find(this.removeSelector).length > 0
    }

    _hasAddControl() {
        return this.element.find(this.addSelector).length > 0
    }

    _attachEvents() {
        this.element.on('click', this.removeSelector, (e) => this.removeFromList(e))
        this.element.on('click', this.addSelector, (e) => this.addToList(e))
    }

    _addCallbacks() {
        this.element.bind('managed_field:add', this.options.add);
        this.element.bind('managed_field:remove', this.options.remove);
    }

    _manageFocus() {
        $(this.element).find(this.listClass).children('li').last().find('.form-control').focus();
    }

    addToList( event ) {
        event.preventDefault();
        let $listing = $(event.target).closest(this.inputTypeClass).find(this.listClass)
        let $activeField = $listing.children('li').last()

        if (this.inputIsEmpty($activeField)) {
            this.displayEmptyWarning();
        } else {
            this.clearEmptyWarning();
            $listing.append(this._newField($activeField));
        }

        this._manageFocus()
    }

    inputIsEmpty($activeField) {
        return $activeField.children('input.multi-text-field').val() === '';
    }

    _newField ($activeField) {
        var $newField = this.createNewField($activeField);
        return $newField;
    }

    // [hyc-override] - Update the field ID to be unique
    _updateFieldId($field) {
        let currentId = $field.attr('id');
        let idParts = currentId.split('_');

        if (idParts.length === 1) {
            $field.attr('id', `${currentId}_1`)
        } else {
            let id = parseInt(idParts[idParts.length - 1])

            if (isNaN(id)) {
                $field.attr('id', `${currentId}_1`);
                $field.attr('labelledby', `${currentId}_1`);
            } else {
                id += 1;
                $field.attr('id', `${idParts[0]}_${idParts[1]}_${id}`);
                $field.attr('labelledby', `${idParts[0]}_${idParts[1]}_${id}`);
            }
        }

        return $field;
    }

    createNewField($activeField) {
        let $newField = $activeField.clone();
        // [hyc-override] - Remove TinyMCE editor before cloning, otherwise we are left with a dead copy of it
        let isTinyMce = $newField.children(".tinymce").length > 0;
        if (isTinyMce) {
            $newField.children(".tox-tinymce").remove();
        }
        let $newChildren = this.createNewChildren($newField);
        // [hyc-override] - Reinitialize TinyMCE editor on the new copy of the field
        if (isTinyMce) {
            const tinyMCEConfig = this.tinyMCEConfig;
            setTimeout(function() {
                $($newChildren[0]).show();
                tinymce.init({
                  ...tinyMCEConfig,
                  selector: '#' + $newChildren[0].id
                });
            }, 100);
        }
        this.element.trigger("managed_field:add", $newChildren);
        return $newField;
    }

    clearEmptyWarning() {
        let $listing = $(this.listClass, this.element)
        $listing.children(this.warningClass).remove();
    }

    displayEmptyWarning() {
        let $listing = $(this.listClass, this.element)
        var $warningMessage  = $("<div class=\'message has-warning\'>cannot add another with empty field</div>");
        $listing.children(this.warningClass).remove();
        $listing.append($warningMessage);
    }

    removeFromList( event ) {
        event.preventDefault();
        var $field = $(event.target).parents(this.fieldWrapperClass).remove();
        this.element.trigger("managed_field:remove", $field);

        this._manageFocus();
    }

    destroy() {
        $(this.fieldWrapperClass, this.element).removeClass("input-append");
        this.element.removeClass("managed");
    }

    getFieldLabel($element, options) {
        var label = '';
        var $label = $element.find("label").first();
        if ($label.length && options.labelControls) {
            var label = $label.data('label') || $.trim($label.contents().filter(function() { return this.nodeType === 3; }).text());
            label = ' ' + label;
        }

        return label;
    }

    createAddHtml(options) {
        var $addHtml  = $(options.addHtml);
        $addHtml.find('.controls-add-text').html(options.addText + options.label);
        return $addHtml;
    }

    createRemoveHtml(options) {
        var $removeHtml = $(options.removeHtml);
        $removeHtml.find('.controls-remove-text').html(options.removeText);
        $removeHtml.find('.controls-field-name-text').html(options.label);
        return $removeHtml;
    }

    createNewChildren(clone) {
        let $newChildren = $(clone).children(this.inputTypeClass);
        $newChildren.val('').removeAttr('required');
        $newChildren.first().focus();
        // [hyc-override] - Update the field ID to be unique
        return this._updateFieldId($newChildren.first());
    }
}