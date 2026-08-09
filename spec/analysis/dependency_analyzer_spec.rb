require 'spec_helper'
require_relative '../../lib/analysis/dependency_analyzer'
require_relative '../../lib/dependency_resolver'
require_relative '../../lib/dependency_walker'
require_relative '../../lib/graph/graph_builder'

RSpec.describe DependencyAnalyzer do
  let(:project_map) { { models: {} } }
  let(:project_path) { '/fake/path' }
  let(:model_name) { 'User' }

  subject(:analyzer) { described_class.new(project_map, project_path) }

  # Test doubles
  let(:resolver) { instance_double(DependencyResolver) }
  let(:graph_builder) { instance_double(GraphBuilder) }
  let(:walker) { instance_double(DependencyWalker) }
  let(:graph) { { model: 'User', associations: {} } }

  before do
    allow(DependencyResolver).to receive(:new).and_return(resolver)
    allow(GraphBuilder).to receive(:new).and_return(graph_builder)
    allow(DependencyWalker).to receive(:new).and_return(walker)
  end

  describe '#initialize' do
    it 'initializes with a project_map and project_path' do
      expect(analyzer.instance_variable_get(:@project_map)).to eq(project_map)
      expect(analyzer.instance_variable_get(:@project_path)).to eq(project_path)
    end
  end

  describe '#analyze' do
    context 'when direct dependencies are found' do
      let(:direct_deps) do
        {
          models: ['Post', 'Comment'],
          controllers: ['UsersController'],
          policies: ['UserPolicy']
        }
      end

      before do
        allow(resolver).to receive(:build).with(model_name).and_return(direct_deps)
        allow(graph_builder).to receive(:build).with(model_name).and_return(graph)
      end

      it 'orchestrates the analysis and returns the correct structure' do
        allow(walker).to receive(:walk_models).with(graph).and_return(['Post', 'Comment', 'Author', 'Category'])
        
        result = analyzer.analyze(model_name)

        expect(result).to eq({
          target: 'User',
          direct_dependencies: direct_deps,
          transitive_dependencies: ['Author', 'Category']
        })
      end

      it 'correctly calculates transitive dependencies, excluding direct ones and removing duplicates' do
        walker_result = ['Post', 'Comment', 'Author', 'Category', 'Author']
        allow(walker).to receive(:walk_models).with(graph).and_return(walker_result)
        
        result = analyzer.analyze(model_name)
        
        expect(result[:transitive_dependencies]).to match_array(['Author', 'Category'])
      end

      it 'handles cases where walker returns only direct dependencies' do
        allow(walker).to receive(:walk_models).with(graph).and_return(['Post', 'Comment'])
        
        result = analyzer.analyze(model_name)
        
        expect(result[:transitive_dependencies]).to be_empty
      end

      it 'handles cases where direct dependency models are empty' do
        direct_deps_no_models = direct_deps.merge(models: [])
        allow(resolver).to receive(:build).with(model_name).and_return(direct_deps_no_models)
        allow(walker).to receive(:walk_models).with(graph).and_return(['Author', 'Category'])
        
        result = analyzer.analyze(model_name)
        
        expect(result[:transitive_dependencies]).to match_array(['Author', 'Category'])
      end
    end

    context 'when DependencyResolver returns nil' do
      before do
        allow(resolver).to receive(:build).with(model_name).and_return(nil)
      end

      it 'returns nil' do
        expect(analyzer.analyze(model_name)).to be_nil
      end

      it 'does not invoke GraphBuilder' do
        expect(GraphBuilder).not_to receive(:new)
        analyzer.analyze(model_name)
      end

      it 'does not invoke DependencyWalker' do
        expect(DependencyWalker).not_to receive(:new)
        analyzer.analyze(model_name)
      end
    end

    context 'orchestration verification' do
      let(:direct_deps) { { models: ['Post'] } }

      before do
        allow(resolver).to receive(:build).and_return(direct_deps)
        allow(graph_builder).to receive(:build).and_return(graph)
        allow(walker).to receive(:walk_models).and_return([])
      end

      it 'creates DependencyResolver with the correct arguments' do
        expect(DependencyResolver).to receive(:new).with(project_map, project_path).and_return(resolver)
        analyzer.analyze(model_name)
      end

      it 'calls build on the resolver with the model name' do
        expect(resolver).to receive(:build).with(model_name)
        analyzer.analyze(model_name)
      end

      it 'creates GraphBuilder with the correct project_map' do
        expect(GraphBuilder).to receive(:new).with(project_map).and_return(graph_builder)
        analyzer.analyze(model_name)
      end

      it 'calls build on the graph_builder with the model name' do
        expect(graph_builder).to receive(:build).with(model_name)
        analyzer.analyze(model_name)
      end

      it 'calls walk_models on the walker with the graph from the builder' do
        expect(walker).to receive(:walk_models).with(graph)
        analyzer.analyze(model_name)
      end
    end

    context 'when GraphBuilder returns a nil graph' do
       let(:direct_deps) { { models: ['Post'] } }
      
      before do
        allow(resolver).to receive(:build).with(model_name).and_return(direct_deps)
        allow(graph_builder).to receive(:build).with(model_name).and_return(nil)
      end

      it 'passes nil to DependencyWalker and proceeds' do
        # Based on DependencyWalker's contract, it returns [] for nil input
        allow(walker).to receive(:walk_models).with(nil).and_return([])
        
        result = analyzer.analyze(model_name)
        
        expect(result[:transitive_dependencies]).to eq([])
        expect(walker).to have_received(:walk_models).with(nil)
      end
    end
  end
end
