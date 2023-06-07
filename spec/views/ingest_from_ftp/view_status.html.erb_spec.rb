# frozen_string_literal: true
require 'rails_helper'
RSpec.describe 'ingest_from_ftp/view_status', type: :view do
  context 'with proquest selected' do
    before(:each) do
      assign(:source, 'proquest')
      assign(:status_results, {
        'etdadmin_upload_3806.zip' => {
          'status' => 'Complete',
          'status_timestamp' => '2023-05-20 16:27:56 -0400',
          'error' => nil
        },
        'etdadmin_upload_942402.zip' => {
          'status' => 'Failed',
          'status_timestamp' => '2023-05-20 15:24:12 -0400',
          'error' => [{
            'message' => 'Totally not working',
            'trace' => ['lines of code', 'in a stacktrace']
          }]
        }
      })
    end

    it 'renders list of proquest statuses' do
      render
      assert_select 'tr:first>td', text: 'etdadmin_upload_3806.zip', count: 1
      assert_select 'tr:first>td', text: '2023-05-20 20:27:56 UTC', count: 1
      assert_select 'tr:first>td', text: 'Complete', count: 1
      assert_select 'tr:first>td>a', text: 'View errors', count: 0
      assert_select 'tr:last>td', text: 'etdadmin_upload_942402.zip', count: 1
      assert_select 'tr:last>td', text: '2023-05-20 19:24:12 UTC', count: 1
      assert_select 'tr:last>td', text: 'Failed', count: 1
      assert_select 'tr:last>td>a', text: 'View errors', count: 1
      assert_select '.modal-title', text: 'Errors for etdadmin_upload_942402.zip', count: 1
      assert_select '.modal-header > .modal-title', text: 'Errors for etdadmin_upload_942402.zip', count: 1
      assert_select '.modal-body > h4', text: 'Totally not working', count: 1
    end
  end
end
