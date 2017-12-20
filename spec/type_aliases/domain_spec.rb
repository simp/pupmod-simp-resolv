require 'spec_helper'

describe 'Resolv::Domain' do
  context 'with valid resolv.conf fields' do
    it { is_expected.to allow_value('test.com') }
    it { is_expected.to allow_value('test.') }
    it { is_expected.to allow_value('0.test-test.test') }
    it { is_expected.to allow_value('.') }
  end

  context 'with silly things' do
    it { is_expected.not_to allow_value("test-.com") }
    it { is_expected.not_to allow_value("test.0") }
    it { is_expected.not_to allow_value([]) }
    it { is_expected.not_to allow_value('' ) }
    it { is_expected.not_to allow_value("test.c m") }
    it { is_expected.not_to allow_value("test.com\n") }
    it { is_expected.not_to allow_value(:undef) }
  end
end
