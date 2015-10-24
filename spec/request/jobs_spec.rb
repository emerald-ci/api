require "emerald/api/workers/job_worker"

RSpec.describe Emerald::API do
  before do
    @user = make_user("login" => "flower-pot")
    login_as @user
  end

  let!(:job) { FactoryGirl.create(:job) }

  describe "[GET] /jobs/:id" do
    context "when job exists" do
      it "returns that single job" do
        get "/api/v1/jobs/#{job.id}"

        expect(json_response).to eq({
          id: job.id,
          build_id: job.build.id,
          state: "passed",
          started_at: "2015-01-01T00:00:00.000Z",
          finished_at: "2015-01-01T00:00:00.000Z",
          project_id: job.build.project.id,
        })
      end
    end
  end

  describe "[GET] /jobs/:id/log" do
    context "when requesting plaintext log" do
      it "returns log as plain text" do
        get "/api/v1/jobs/#{job.id}/log.raw"

        expect(last_response.body).to eq <<-LOG.strip_heredoc.chomp
          not colored
          \e[33mcolored\e[0m
          not colored
        LOG
      end
    end

    context "when requesting log as json" do
      it "returns log as an array of lines with ansi colors converted to html" do
        get "/api/v1/jobs/#{job.id}/log"

        expect(last_response.body).to eq <<-LOG.strip_heredoc.chomp
          not colored
          <span class="yellow">colored</span>
          not colored
        LOG
      end
    end
  end
end
