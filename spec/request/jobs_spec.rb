require "emerald/api/workers/job_worker"

RSpec.describe do
  before do
    @user = make_user("login" => "flower-pot")
    login_as @user
    @project = FactoryGirl.create(:project)
  end

  describe "[GET] /jobs/:id" do
    context "when job exists" do
      it "returns that single job"
    end
  end

  describe "[GET] /jobs/:id/log" do
    context "when requesting plaintext log" do
      it "returns log as plain text"
    end

    context "when requesting log as json" do
      it "returns log as an array of lines with ansi colors converted to html"
    end
  end
end
