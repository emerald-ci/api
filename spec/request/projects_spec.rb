RSpec.describe do
  before do
    @user = make_user('login' => 'flower-pot')
    login_as @user
  end

  describe '[GET] /projects' do
    it 'returns a list of projects' do
      project = FactoryGirl.create(:project)

      get '/projects', 'CONTENT_TYPE' => 'application/json'

      expect(last_response.body).to eq ([
        {
          project: {
            id: project.id,
            git_url: 'https://github.com/emerald-ci/ruby-example'
          }
        }
      ].to_json)
    end
  end

  describe '[POST] /projects' do
    it 'returns a list of projects' do
      project_json = {
        project: {
          git_url: 'https://github.com/emerald-ci/ruby-example'
        }
      }.to_json

      expect {
        post '/projects', project_json, 'CONTENT_TYPE' => 'application/json'
      }.to change{ Project.count }.by(1)

      project = Project.last
      expect(last_response.body).to eq ({
        project: {
          id: project.id,
          git_url: 'https://github.com/emerald-ci/ruby-example'
        }
      }.to_json)
    end
  end

  describe '[GET] /projects/:id' do
    context 'project exists' do
      it 'returns a single project' do
        project = FactoryGirl.create(:project)

        get "/projects/#{project.id}", 'CONTENT_TYPE' => 'application/json'

        expect(last_response.body).to eq ({
          project: {
            id: project.id,
            git_url: 'https://github.com/emerald-ci/ruby-example'
          }
        }.to_json)
      end
    end
  end
end
