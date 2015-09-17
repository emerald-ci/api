require 'sidekiq/testing'
Sidekiq::Testing.fake!

require 'emerald/api/workers/job_worker'

RSpec.describe do
  before do
    @user = make_user('login' => 'flower-pot')
    login_as @user
    @project = FactoryGirl.create(:project)
  end

  describe '[POST] /projects/:id/builds/trigger/github' do
    it 'enqueues a job to execute the build' do
      expect {
        post "/projects/#{@project.id}/builds/trigger/github", {}.to_json, 'CONTENT_TYPE' => 'application/json'
      }.to change { JobWorker.jobs.size }.by(1)

      expect(last_response.body).to eq ({
        message: 'Job has been enqueued.'
      }.to_json)
    end
  end
end
