# frozen_string_literal: true
require 'rails_helper'

RSpec.describe HycDownloadStat, type: :model do
  describe 'scopes' do
    let!(:stat1) { FactoryBot.create(:hyc_download_stat, fileset_id: 'fs1', work_id: 'w1', admin_set_id: 'as1', work_type: 'Article', date: '2024-07-01', download_count: 10) }
    let!(:stat2) { FactoryBot.create(:hyc_download_stat, fileset_id: 'fs2', work_id: 'w2', admin_set_id: 'as2', work_type: 'Dataset', date: '2024-07-01', download_count: 5) }
    let!(:stat3) { FactoryBot.create(:hyc_download_stat, fileset_id: 'fs1', work_id: 'w1', admin_set_id: 'as1', work_type: 'Article', date: '2024-08-01', download_count: 20) }

    it 'returns records with a specific fileset_id and date range' do
      expect(HycDownloadStat.with_fileset_id_and_date('fs1', '2024-07-01', '2024-07-31')).to include(stat1)
      expect(HycDownloadStat.with_fileset_id_and_date('fs1', '2024-07-01', '2024-07-31')).not_to include(stat3)
    end

    it 'returns records with a specific work_id and date range' do
      expect(HycDownloadStat.with_work_id_and_date('w1', '2024-07-01', '2024-07-31')).to include(stat1)
      expect(HycDownloadStat.with_work_id_and_date('w1', '2024-07-01', '2024-07-31')).not_to include(stat3)
    end

    it 'returns records with a specific admin_set_id' do
      expect(HycDownloadStat.with_admin_set_id('as1')).to include(stat1, stat3)
      expect(HycDownloadStat.with_admin_set_id('as1')).not_to include(stat2)
    end

    it 'returns records with a specific work_type' do
      expect(HycDownloadStat.with_work_type('Article')).to include(stat1, stat3)
      expect(HycDownloadStat.with_work_type('Article')).not_to include(stat2)
    end

    it 'returns records with a specific fileset_id' do
      expect(HycDownloadStat.with_fileset_id('fs1')).to include(stat1, stat3)
      expect(HycDownloadStat.with_fileset_id('fs1')).not_to include(stat2)
    end

    it 'returns records with a specific work_id' do
      expect(HycDownloadStat.with_work_id('w1')).to include(stat1, stat3)
      expect(HycDownloadStat.with_work_id('w1')).not_to include(stat2)
    end

    it 'returns records within a specific date range' do
      expect(HycDownloadStat.within_date_range('2024-07-01', '2024-07-31')).to include(stat1, stat2)
      expect(HycDownloadStat.within_date_range('2024-07-01', '2024-07-31')).not_to include(stat3)
    end
  end
end
