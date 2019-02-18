require 'rails_helper'

RSpec.describe Hyc::Validators::DateValidator do
  describe '#validate' do
    let(:validator) { described_class.new }
    let(:correct_year) { '1925' }
    let(:incorrect_year) { '25-01' }
    let(:record) {}

    context 'When an article has an proper year with other characters' do
      let(:record) { Article.new(date_created: incorrect_year) }
      let(:incorrect_year) { '1925asdfaafasdfasd' }
      it 'sets the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to eq ['Please enter a valid date']
      end
    end

    context 'When an article has an improper year that is only characters' do
      let(:record) { Article.new(date_created: incorrect_year) }
      let(:incorrect_year) { 'asdf' }

      it 'sets the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to eq ['Please enter a valid date']
      end
    end

    context 'When an article has a year with more than four digits' do
      let(:record) { Article.new(date_created: incorrect_year) }
      let(:incorrect_year) { '20504' }

      it 'sets the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to eq ['Please enter a valid date']
      end
    end

    context 'When an article has an improper year that is not of length 4' do
      let(:record) { Article.new(date_created: incorrect_year) }
      let(:incorrect_year) { '205' }

      it 'sets the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to eq ['Please enter a valid date']
      end
    end

    context 'When an article has a year without a day' do
      let(:record) { Article.new(date_created: incorrect_year) }
      let(:incorrect_year) { '1800/02' }

      it 'sets the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to eq ['Please enter a valid date']
      end
    end

    context 'When an article has a YYYY year' do
      let(:record) { Article.new(date_created: correct_year) }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has a YYYY-MM-DD year' do
      let(:record) { Article.new(date_created: '2019-01-01') }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has a YYYY/MM/DD year' do
      let(:record) { Article.new(date_created: '2019/01/01') }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has a YYYY\MM\DD year' do
      let(:record) { Article.new(date_created: '2019\01\01') }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has an Unknown year' do
      let(:record) { Article.new(date_created: 'Unknown') }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has a "Circa Year" year' do
      let(:record) { Article.new(date_created: 'Circa 1900') }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has a "Century" year' do
      let(:record) { Article.new(date_created: '1900s') }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has a "Decade" year' do
      let(:record) { Article.new(date_created: '1980s') }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has a range of years' do
      let(:record) { Article.new(date_created: '1980 to 2000') }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has a word month with year' do
      let(:record) { Article.new(date_created: 'July 1900') }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has a word month, number day with year' do
      let(:record) { Article.new(date_created: 'July 1 1900') }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has a word month, number day with comma and year' do
      let(:record) { Article.new(date_created: 'July 1, 1900') }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has a word month, number day with suffix, and comma with and year' do
      let(:record) { Article.new(date_created: 'July 1st, 1900') }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has a nil year' do
      let(:record) { Article.new(date_created: nil) }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end

    context 'When an article has an empty year' do
      let(:record) { Article.new(date_created: '') }
      it 'does not set the error on the record' do
        validator.validate(record)
        expect(record.errors['date_created']).to be_blank
      end
    end
  end
end