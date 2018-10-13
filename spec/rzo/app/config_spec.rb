require 'spec_helper'

RSpec.describe Rzo::App::Config do
  # rubocop:disable Security/YAMLLoad
  let(:opts) { YAML.load(fixture('config/opts.yaml')) }
  # rubocop:enable Security/YAMLLoad
  # The personal configuration file only.
  let(:personal_config) { YAML.safe_load(fixture('_home_rizzo.yaml')) }
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:subcommand) { described_class.new(opts, stdout, stderr) }

  before :each do
    expect(subcommand).to receive(:load_rizzo_config).and_return(personal_config)
  end

  describe 'baseline behavior' do
    it 'runs with 0 exit code' do
      expect(subcommand.run).to eq(0)
    end
  end

  describe 'precedence list of control repositories' do
    subject 'control_repos' do
      subcommand.run
      subcommand.config['control_repos']
    end

    context 'with no .rizzo.yaml in the CWD' do
      it 'uses the configured control_repos as is' do
        control_repos = personal_config['control_repos'].dup
        expect(subject).to eq(control_repos)
      end
      it 'is a unique list of control repos' do
        expect(subject.uniq).to eq(subject)
      end
    end

    context 'when .rizzo.yaml exists in the CWD' do
      before :each do
        expect(subcommand).to receive(:project_dir).with(Dir.pwd).and_return(Dir.pwd)
      end
      it 'places the CWD project first in the list' do
        expect(subject.first).to eq(Dir.pwd)
      end
      it 'adds only one control repo' do
        expected_size = 1 + personal_config['control_repos'].size
        expect(subject.size).to eq(expected_size)
      end
      it 'is a unique list of control repos' do
        expect(subject.uniq).to eq(subject)
      end
    end
  end
end
