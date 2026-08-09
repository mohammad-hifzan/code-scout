require 'spec_helper'
require 'fileutils'
require 'tmpdir'

require_relative '../../lib/indexing/project_index'
require_relative '../../lib/analysis/model_analyzer'
require_relative '../../lib/analysis/controller_analyzer'
require_relative '../../lib/analysis/view_analyzer'
require_relative '../../lib/context/context_builder'
require_relative '../../lib/analysis/dependency_analyzer'
require_relative '../../lib/analysis/impact_analyzer'

RSpec.describe ProjectIndex do
  subject(:project_index) { described_class.new(project_map, project_path) }

  let(:project_path) { '/fake/project' }
  let(:project_map) do
    {
      models: {
        'User' => { path: '/fake/project/app/models/user.rb' },
        'Post' => { path: '/fake/project/app/models/post.rb' }
      },
      controllers: {
        'UsersController' => { path: '/fake/project/app/controllers/users_controller.rb' }
      },
      views: {
        'users' => ['/fake/project/app/views/users/index.html.erb']
      }
    }
  end

  # Create doubles for all dependencies
  let(:model_analyzer) { instance_double(ModelAnalyzer) }
  let(:controller_analyzer) { instance_double(ControllerAnalyzer) }
  let(:view_analyzer) { instance_double(ViewAnalyzer) }
  let(:context_builder) { instance_double(ContextBuilder) }
  let(:dependency_analyzer) { instance_double(DependencyAnalyzer) }
  let(:impact_analyzer) { instance_double(ImpactAnalyzer) }

  before do
    # Stub the initializers of the dependencies to return our doubles
    allow(ModelAnalyzer).to receive(:new).and_return(model_analyzer)
    allow(ControllerAnalyzer).to receive(:new).and_return(controller_analyzer)
    allow(ViewAnalyzer).to receive(:new).and_return(view_analyzer)
    allow(ContextBuilder).to receive(:new).and_return(context_builder)
    allow(DependencyAnalyzer).to receive(:new).and_return(dependency_analyzer)
    allow(ImpactAnalyzer).to receive(:new).and_return(impact_analyzer)

    # Stub the analyze/build methods to return predictable data
    allow(model_analyzer).to receive(:analyze).and_return({ model_analysis: 'done' })
    allow(controller_analyzer).to receive(:analyze).and_return({ controller_analysis: 'done' })
    allow(view_analyzer).to receive(:analyze).and_return({ view_analysis: 'done' })
    allow(context_builder).to receive(:build).and_return({ context: 'built' })
    allow(dependency_analyzer).to receive(:analyze).and_return({ dependencies: 'analyzed' })
    allow(impact_analyzer).to receive(:analyze).and_return({ impact: 'analyzed' })
  end

  describe '#model' do
    context 'when the model exists' do
      it 'builds the model using all relevant analyzers' do
        result = project_index.model('User')

        expect(model_analyzer).to have_received(:analyze).with('/fake/project/app/models/user.rb')
        expect(context_builder).to have_received(:build).with('User')
        expect(dependency_analyzer).to have_received(:analyze).with('User')
        expect(impact_analyzer).to have_received(:analyze).with('User')

        expect(result).to eq({
          analyzer: { model_analysis: 'done' },
          context: { context: 'built' },
          dependency: { dependencies: 'analyzed' },
          impact: { impact: 'analyzed' }
        })
      end

      it 'caches the result for subsequent calls' do
        project_index.model('User') # First call
        project_index.model('User') # Second call

        # Verify that the analyzers were only called once
        expect(model_analyzer).to have_received(:analyze).once
        expect(context_builder).to have_received(:build).once
        expect(dependency_analyzer).to have_received(:analyze).once
        expect(impact_analyzer).to have_received(:analyze).once
      end
    end

    context 'when the model does not exist' do
      it 'returns nil' do
        expect(project_index.model('NonExistentModel')).to be_nil
      end

      it 'does not call any analyzers' do
        project_index.model('NonExistentModel')
        expect(model_analyzer).not_to have_received(:analyze)
        expect(context_builder).not_to have_received(:build)
      end
    end
  end

  describe '#controller' do
    context 'when the controller exists' do
      it 'builds the controller using the controller analyzer' do
        result = project_index.controller('UsersController')

        expect(controller_analyzer).to have_received(:analyze).with('/fake/project/app/controllers/users_controller.rb')
        expect(result).to eq({
          analyzer: { controller_analysis: 'done' }
        })
      end

      it 'caches the result for subsequent calls' do
        project_index.controller('UsersController')
        project_index.controller('UsersController')
        expect(controller_analyzer).to have_received(:analyze).once
      end
    end

    context 'when the controller does not exist' do
      it 'returns nil' do
        expect(project_index.controller('NonExistentController')).to be_nil
      end

      it 'does not call the analyzer' do
        project_index.controller('NonExistentController')
        expect(controller_analyzer).not_to have_received(:analyze)
      end
    end
  end

  describe '#view' do
    let(:view_path) { '/fake/project/app/views/users/index.html.erb' }

    context 'when the view file exists' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(view_path).and_return(true)
      end

      it 'builds the view using the view analyzer' do
        result = project_index.view(view_path)

        expect(view_analyzer).to have_received(:analyze).with(view_path)
        expect(result).to eq({
          analyzer: { view_analysis: 'done' }
        })
      end

      it 'caches the result for subsequent calls' do
        project_index.view(view_path)
        project_index.view(view_path)
        expect(view_analyzer).to have_received(:analyze).once
      end
    end

    context 'when the view file does not exist' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('/fake/project/app/views/non_existent.html.erb').and_return(false)
      end
      let(:non_existent_path) { '/fake/project/app/views/non_existent.html.erb' }

      it 'returns nil' do
        expect(project_index.view(non_existent_path)).to be_nil
      end

      it 'does not call the analyzer' do
        project_index.view(non_existent_path)
        expect(view_analyzer).not_to have_received(:analyze)
      end
    end
  end
end
