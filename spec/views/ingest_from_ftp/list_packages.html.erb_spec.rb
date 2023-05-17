# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'ingest_from_ftp/list_packages', type: :view do
  context 'with proquest selected' do
    before(:each) do
      assign(:provider, 'proquest')
      assign(:needs_revision_flag, false)
      assign(:package_results, [
        {
          filename: 'etdadmin_upload_3806.zip',
          last_modified: Time.new(2020, 12, 31, 8, 8, 8)
        },
        {
          filename: 'etdadmin_upload_942402.zip',
          last_modified: Time.new(2021, 1, 1, 5, 5, 5)
        }
      ])
    end

    it 'renders list of proquest packages' do
      render
      assert_select 'tr:first>td', text: 'etdadmin_upload_3806.zip', count: 1
      assert_select 'tr:first>td', text: 'Dec 31, 2020', count: 1
      assert_select 'tr:last>td', text: 'etdadmin_upload_942402.zip', count: 1
      assert_select 'tr:last>td', text: 'Jan 1, 2021', count: 1
      assert_select 'a.active', text: 'Proquest', count: 1
    end
  end

  context 'with sage selected' do
    before(:each) do
      assign(:provider, 'sage')
      assign(:needs_revision_flag, true)
      assign(:package_results, [
        {
          filename: '1177_01605976231158397.zip',
          last_modified: Time.new(2022, 8, 20, 8, 8, 8),
          is_revision: false
        },
        {
          filename: 'JPX_2021_8_10.1177_23743735211067313.r2022-01-21.zip',
          last_modified: Time.new(2022, 9, 5, 5, 5, 5),
          is_revision: true
        }
      ])
    end

    it 'renders list of proquest packages' do
      render
      assert_select 'tr:first>td', text: '1177_01605976231158397.zip', count: 1
      assert_select 'tr:first>td', text: 'Aug 20, 2022', count: 1
      assert_select 'tr:first>td', text: 'false', count: 1
      assert_select 'tr:last>td', text: 'JPX_2021_8_10.1177_23743735211067313.r2022-01-21.zip', count: 1
      assert_select 'tr:last>td', text: 'Sep 5, 2022', count: 1
      assert_select 'tr:last>td', text: 'true', count: 1
      assert_select 'a.active', text: 'Sage', count: 1
    end
  end
end
