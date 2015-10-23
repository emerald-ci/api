require "emerald/api/workers/job_worker"

RSpec.describe Emerald::API do
  before do
    @user = make_user("login" => "flower-pot")
    login_as @user
  end

  let!(:project) { FactoryGirl.create(:project) }

  describe "[GET] /projects/:id/builds" do
    context "when previous builds are present" do
      let!(:build) { FactoryGirl.create( :build, project: project) }

      it "returns an array of builds" do
        get "/api/v1/projects/#{project.id}/builds"

        expect(json_response).to eq([{
          id: build.id,
          project_id: project.id,
          commit: "commit-sha123",
          short_description: "some useful git message with lots of information",
          description: "some useful git message with lots of information",
          created_at: "2015-01-01T00:00:00.000Z",
          updated_at: "2015-01-01T00:00:00.000Z",
          latest_job: nil,
        }])
      end
    end

    context "when no previous builds are present" do
      it "returns an empty array of builds" do
        get "/api/v1/projects/#{project.id}/builds"

        expect(json_response).to eq []
      end
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
          post "/api/v1/projects/#{project.id}/builds/trigger/github", webhook_payload, "CONTENT_TYPE" => "application/json"
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
          post "/api/v1/projects/#{project.id}/builds/trigger/manual", "", "CONTENT_TYPE" => "application/json"
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
    let!(:build) { FactoryGirl.create( :build, project: project) }

    context "when build exists" do
      it "returns the single build" do
        get "/api/v1/builds/#{build.id}"

        expect(json_response).to eq({
          id: build.id,
          project_id: project.id,
          commit: "commit-sha123",
          short_description: "some useful git message with lots of information",
          description: "some useful git message with lots of information",
          created_at: "2015-01-01T00:00:00.000Z",
          updated_at: "2015-01-01T00:00:00.000Z",
          latest_job: nil,
        })
      end
    end
  end

  describe "[GET] /builds/:id/jobs" do
    let!(:build) { FactoryGirl.create( :build, project: project) }

    context "when jobs exists for this build" do
      let!(:job) { FactoryGirl.create( :job, build: build) }

      it "returns an array of jobs" do
        get "/api/v1/builds/#{build.id}/jobs"

        expect(json_response).to eq([{
          id: job.id,
          build_id: build.id,
          state: "passed",
          started_at: "2015-01-01T00:00:00.000Z",
          finished_at: "2015-01-01T00:00:00.000Z",
          project_id: project.id,
        }])
      end
    end

    context "when no jobs exists for this build" do
      it "returns an empty array of jobs" do
        get "/api/v1/builds/#{build.id}/jobs"

        expect(json_response).to eq []
      end
    end
  end
end
