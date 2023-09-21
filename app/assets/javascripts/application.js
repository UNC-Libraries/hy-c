// [hyc-override] based off: https://github.com/samvera/hyrax/blob/main/.dassie/app/assets/javascripts/application.js
// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
// [hyc-override] not using activestorage
// # require activestorage
//= require turbolinks

// Required by Blacklight
//= require jquery3
// [hyc-override] explicitly include jquery-ui here before bootstrap, otherwise there will be conflicts with tooltips
//= require jquery-ui
//= require rails-ujs
//= require popper
//= require twitter/typeahead
//= require bootstrap
//= require jquery.dataTables
//= require dataTables.bootstrap4
//= require blacklight/blacklight
//= require blacklight_gallery

// [hyc-override] skipping import of all subtrees
// # require_tree .
//= require hyrax
//
// [hyc-override] advanced search blacklight plugins
//= require 'blacklight_advanced_search'
// [hyc-override] blacklight_range_limit plugin and dependency
//= require 'bootstrap-slider'
//= require 'blacklight_range_limit'

// [hyc-override] almond seems to be needed here even though its specified in hyrax includes
//= require almond
// [hyc-override] Enable type ahead in advanced search
//= require chosen/chosen.jquery.min
// [hyc-override] unc custom scripts
//= require unc/unc_visibility_component
//= require unc/unc_save_work_control
//= require unc/unc_editor
//= require unc/unc_custom
//= require person_objects

// [hyc-override] add bulkrax
//= require bulkrax/application
