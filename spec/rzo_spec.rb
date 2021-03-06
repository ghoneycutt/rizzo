require 'spec_helper'

RSpec.describe Rzo do
  it 'has a version number' do
    expect(Rzo::VERSION).not_to be nil
  end

  it 'responds to .version' do
    expect(described_class).to respond_to :version
  end

  it '.version == Rizzo::VERSION' do
    expect(described_class.version).to eq(Rzo::VERSION)
  end

  let(:argv) { [] }
  let(:rizzo_config) { '_home_rizzo.yaml' }
  let(:expected_output) { fixture('Vagrantfile.expected.1') }
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }

  let :app do
    # Prevent trollop calling Kernel#exit()
    allow(Rzo::Trollop).to receive(:educate)
    # Configuration file loaded from spec fixture
    example_config = YAML.safe_load(fixture(rizzo_config))
    allow(Rzo::App::Subcommand).to receive(:load_rizzo_config).and_return(example_config)
    # The app instance under test
    Rzo::App.new(argv, ENV.to_hash, stdout, stderr)
  end

  describe 'rzo app with no options or arguments' do
    it 'educates the user (e.g. --help)' do
      expect(Rzo::Trollop).to receive(:educate)
      app.run
    end
  end

  describe 'generate' do
    let(:argv) { ['generate'] }
    describe 'output Vagrantfile' do
      # The actual Vagrantfile content written to disk
      subject do
        output_file = StringIO.new
        expect(app.generate).to receive(:write_file).with('Vagrantfile').and_yield(output_file)
        expect(app.generate).to receive(:timestamp).and_return('2017-08-18 13:00:09 -0700')
        allow(app.generate).to receive(:validate_existence).and_return(nil)
        expect(Rzo).to receive(:version).and_return('0.1.0')
        app.run
        output_file.rewind
        output_file.read
      end

      it 'has no nodes' do
        expect(subject).to eq(fixture('Vagrantfile.expected.1'))
      end

      context 'with a full config file' do
        let(:rizzo_config) { '_complete_rizzo.yaml' }

        it 'has many nodes' do
          expect(subject).to eq(fixture('_complete_Vagrantfile.rb'))
        end
      end

      context 'with a config file that has null values' do
        let(:rizzo_config) { '_test_nil_rizzo.yaml' }

        it 'omits null values' do
          expect(subject).to eq(fixture('_test_nil_Vagrantfile.rb'))
        end
      end
    end
  end

  describe 'generate errors' do
    let(:argv) { ['generate'] }
    describe 'raise errors' do
      # The actual Vagrantfile content written to disk
      subject do
        allow(app.generate).to receive(:validate_existence).and_return(nil)
        app.run
      end
      context 'with invalid nodes' do
        let(:rizzo_config) { '_invalid_nodes.yaml' }

        it 'fails' do
          expect(subject).to eq(2)
        end
      end
    end
  end
end
