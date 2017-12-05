require 'spec_helper'

describe 'Resolv::Sortlist' do
  context 'with valid sortlist elements' do
    it { is_expected.to allow_value([]) }
    it { is_expected.to allow_value([
      '111.111.111.111',
      '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
      '1.2.3.4/255.255.255.0',
    ])}
    it { is_expected.to allow_value([
      '1.2.3.1',
      '1.2.3.2',
      '1.2.3.3',
      '1.2.3.4',
      '1.2.3.5',
      '1.2.3.6',
      '1.2.3.7',
      '1.2.3.8',
      '1.2.3.9',
      '1.2.3.10',
    ])}
  end

  context 'with too many sortlist elements' do
    it { is_expected.not_to allow_value([
      '1.2.3.1',
      '1.2.3.2',
      '1.2.3.3',
      '1.2.3.4',
      '1.2.3.5',
      '1.2.3.6',
      '1.2.3.7',
      '1.2.3.8',
      '1.2.3.9',
      '1.2.3.10',
      '1.2.3.11',
    ])}
  end
  context 'with invalid sortlist elements' do
    it { is_expected.not_to allow_value(['1.2.3.4/24']) }
    it { is_expected.not_to allow_value(['999.999.999.999']) }
    it { is_expected.not_to allow_value(['test.com']) }
    it { is_expected.not_to allow_value(:undef) }
  end

  context 'with silly things' do
    it { is_expected.not_to allow_value('test.com') }
    it { is_expected.not_to allow_value(['.']) }
    it { is_expected.not_to allow_value([''] ) }
  end
end

