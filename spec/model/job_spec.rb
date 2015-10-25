RSpec.describe Job do
  let!(:job) { FactoryGirl.create(:job) }

  describe "#add_to_log" do
    it "appends to the existing log" do
      job.add_to_log("\ntest")

      expect(job.reload.log).to eq <<-LOG.strip_heredoc.chomp
        not colored
        \e[33mcolored\e[0m
        not colored
        test
      LOG
    end
  end
end
