require 'spec_helper'

RSpec.describe Rzo::App do
  let(:env) { {} }
  let(:argv) { [] }
  let(:app) { described_class.new(argv, env) }

  describe 'lifecycle api' do
    subject { app }
    it { is_expected.to respond_to(:run) }
    it { is_expected.to respond_to(:opts) }
    it { is_expected.to respond_to(:reset!) }
  end

  describe '#opts' do
    subject { app.opts }

    context 'default' do
      expected = { debug: false, help: false, logto: 'STDERR', syslog: false, verbose: false }

      it { expect(subject[:subcommand]).to be_nil }
      expected.each_pair do |subj, val|
        describe "--#{subj}" do
          subject { app.opts[subj] }
          it { is_expected.to eq(val) }
        end
      end
    end
  end
end
