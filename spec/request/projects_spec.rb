RSpec.describe Emerald::API do
  before do
    @user = make_user("login" => "flower-pot")
    login_as @user
  end

  describe "[GET] /projects" do
    let!(:project) { FactoryGirl.create(:project) }

    it "returns a list of projects" do
      get "/api/v1/projects", "CONTENT_TYPE" => "application/json"

      expect(json_response).to eq ([
        {
          id: project.id,
          name: "test",
          type: "PlainProject",
          latest_build: nil,
          git_url: "https://github.com/emerald-ci/ruby-example"
        }
      ])
    end
  end

  describe "[POST] /projects" do
    it "returns a list of projects" do
      project_json = {
        name: "test",
        git_url: "https://github.com/emerald-ci/ruby-example"
      }.to_json

      expect {
        post "/api/v1/projects", project_json, "CONTENT_TYPE" => "application/json"
      }.to change{ Project.count }.by(1)

      project = Project.last
      expect(json_response).to eq ({
        id: project.id,
        name: "test",
        type: "PlainProject",
        latest_build: nil,
        git_url: "https://github.com/emerald-ci/ruby-example"
      })
    end
  end

  describe "[GET] /projects/:id" do
    context "project exists" do
      let!(:project) { FactoryGirl.create(:project) }

      it "returns a single project" do
        project = FactoryGirl.create(:project)

        get "/api/v1/projects/#{project.id}", "CONTENT_TYPE" => "application/json"

        expect(json_response).to eq ({
          id: project.id,
          name: "test",
          type: "PlainProject",
          latest_build: nil,
          git_url: "https://github.com/emerald-ci/ruby-example"
        })
      end
    end
  end

  describe "[DELETE] /projects/:id" do
    context "when project exists" do
      let!(:project) { FactoryGirl.create(:project) }

      it "deletes the single specified project" do
        expect do
          delete(
            "/api/v1/projects/#{project.id}",
            "CONTENT_TYPE" => "application/json"
          )
        end.to change{Project.count}.by(-1)

        expect(last_response.status).to eq(204)
        expect(Project.exists?(project.id)).to be false
      end
    end
  end
end
