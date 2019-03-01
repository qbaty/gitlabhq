require 'spec_helper'

describe Gitlab::SidekiqMiddleware::MemoryKiller do
  subject { described_class.new }
  let(:pid) { 999 }

  let(:worker) { double(:worker, class: 'TestWorker') }
  let(:job) { { 'jid' => 123 } }
  let(:queue) { 'test_queue' }

  def run
    thread = subject.call(worker, job, queue) { nil }
    thread&.join
  end

  before do
    allow(subject).to receive(:get_rss).and_return(10.kilobytes)
    allow(subject).to receive(:pid).and_return(pid)
  end

  context 'when MAX_RSS is set to 0' do
    before do
      stub_const("#{described_class}::MAX_RSS", 0)
    end

    it 'does nothing' do
      expect(subject).not_to receive(:sleep)

      run
    end
  end

  context 'when MAX_RSS is exceeded' do
    before do
      stub_const("#{described_class}::MAX_RSS", 5.kilobytes)
    end

    it 'sends the STP, TERM and KILL signals at expected times' do
      expect(subject).to receive(:sleep).with(15 * 60).ordered
      expect(Process).to receive(:kill).with('SIGTSTP', pid).ordered

      expect(subject).to receive(:sleep).with(30).ordered
      expect(Process).to receive(:kill).with('SIGTERM', pid).ordered

      expect(subject).to receive(:sleep).with(10).ordered
      expect(Process).to receive(:kill).with('SIGKILL', pid).ordered

      run
    end
  end

  context 'when MAX_RSS is not exceeded' do
    before do
      stub_const("#{described_class}::MAX_RSS", 15.kilobytes)
    end

    it 'does nothing' do
      expect(subject).not_to receive(:sleep)

      run
    end
  end
end
