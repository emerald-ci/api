require "emerald/api/workers/job_worker"

RSpec.describe do
  before do
    @user = make_user("login" => "flower-pot")
    login_as @user
    @project = FactoryGirl.create(:project)
  end

  describe "[GET] /projects/:id/builds" do
    context "when previous builds are present" do
      it "returns an array of builds"
    end

    context "when no previous builds are present" do
      it "returns an empty array of builds"
    end
  end

  describe "[POST] /projects/:id/builds/trigger/github" do
    context "when the project exists" do
      it "enqueues a job to execute the build with the specified commit" do
        webhook_payload = {
          head_commit: {
            id: "sha123",
            message: "Test message"
          }
        }.to_json

        expect {
          post "/api/v1/projects/#{@project.id}/builds/trigger/github", webhook_payload, "CONTENT_TYPE" => "application/json"
        }.to change { JobWorker.jobs.size }.by(1)

        job = Job.last
        expect(json_response).to eq ({
          id: job.id,
          build_id: job.build.id,
          project_id: job.build.project.id,
          state: "not_running",
          started_at: nil,
          finished_at: nil
        })
      end
    end
  end

  describe "[POST] /projects/:id/builds/trigger/github" do
    context "when the project exists" do
      it "enqueues a job to execute the build with from master branch" do
        allow_any_instance_of(Octokit::Client).to receive(:commits).and_return(
          [OpenStruct.new({ commit: { message: "test msg" } })]
        )

        expect do
          post "/api/v1/projects/#{@project.id}/builds/trigger/manual", "", "CONTENT_TYPE" => "application/json"
        end.to change { JobWorker.jobs.size }.by(1)

        job = Job.last
        expect(json_response).to eq ({
          id: job.id,
          build_id: job.build.id,
          project_id: job.build.project.id,
          state: "not_running",
          started_at: nil,
          finished_at: nil
        })
      end
    end
  end

  describe "[GET] /builds/:id" do
    context "when build exists" do
      it "returns the single build"
    end
  end

  describe "[GET] /builds/:id/jobs" do
    context "when jobs exists for this build" do
      it "returns an array of jobs"
    end

    context "when no jobs exists for this build" do
      it "returns an empty array of jobs"
    end
  end
end
