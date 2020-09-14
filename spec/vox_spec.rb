# frozen_string_literal: true

RSpec.describe Vox do
  it 'has a version number' do
    expect(Vox::VERSION).not_to be nil
  end

  describe '.setup_default_logger' do
    let(:info_level) { Logging.level_num(:info) }
    let(:logger) { Logging.logger[described_class] }

    before do
      allow(Logging).to receive(:color_scheme)
      described_class.setup_default_logger
    end

    after { Logging.reset }

    it 'adds a root level' do
      expect(logger.level).to eq info_level
    end

    it 'adds a default color scheme' do
      expect(Logging).to have_received(:color_scheme)
    end

    it 'adds a stdout appender' do
      expect(logger.appenders).not_to be_empty
    end

    it 'adds custom rules as an option hash' do
      Logging.reset
      described_class.setup_default_logger(root_level: :info, 'Vox::Gateway': :warn)
      expect(Logging.logger['Vox::Gateway']).not_to be_nil
    end
  end
end
