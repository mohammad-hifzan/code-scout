# frozen_string_literal: true
require 'spec_helper'
require 'analysis/impact_analyzer'
require 'context/context_builder'
require 'graph/graph_builder'

RSpec.describe ImpactAnalyzer do
  let(:project_map) { {} }
  let(:project_path) { '/fake/project' }
  let(:analyzer) { described_class.new(project_map, project_path) }

  let(:context_builder) { instance_double(ContextBuilder) }
  let(:graph_builder) { instance_double(GraphBuilder) }

  before do
    allow(ContextBuilder).to receive(:new).with(project_map, project_path).and_return(context_builder)
    allow(GraphBuilder).to receive(:new).with(project_map).and_return(graph_builder)
  end

  describe '#analyze' do
    context 'when the model does not exist' do
      it 'returns nil' do
        allow(context_builder).to receive(:build).with('NonExistentModel').and_return(nil)
        expect(analyzer.analyze('NonExistentModel')).to be_nil
      end
    end

    context 'with a simple model with no dependencies' do
      it 'returns a low-risk impact analysis' do
        context = {
          related_models: [],
          primary_controller: nil,
          primary_policy: nil
        }
        graph = { model: 'User', associations: { belongs_to: [], has_many: [], has_one: [] } }

        allow(context_builder).to receive(:build).with('User').and_return(context)
        allow(graph_builder).to receive(:build).with('User').and_return(graph)

        result = analyzer.analyze('User')

        expect(result[:target]).to eq('User')
        expect(result[:score]).to eq(0)
        expect(result[:risk_level]).to eq(:low)
        expect(result[:direct_impact][:models]).to be_empty
        expect(result[:indirect_impact][:models]).to be_empty
      end
    end

    context 'with direct and indirect impacts' do
        it 'calculates score and categorizes impacts correctly' do
          context = {
            related_models: ['/fake/project/app/models/profile.rb'],
            primary_controller: 'UsersController',
            primary_policy: 'UserPolicy'
          }
          # Graph: User -> Post -> Comment
          graph = {
            model: 'User',
            associations: {
              belongs_to: [],
              has_many: [
                { model: 'Post', associations: {
                  belongs_to: [],
                  has_many: [
                    { model: 'Comment', associations: { belongs_to: [], has_many: [], has_one: [] } }
                  ],
                  has_one: []
                } }
              ],
              has_one: []
            }
          }
  
          allow(context_builder).to receive(:build).with('User').and_return(context)
          allow(graph_builder).to receive(:build).with('User').and_return(graph)
  
          result = analyzer.analyze('User')
  
          expect(result[:target]).to eq('User')
          # Score: (Profile * 3) + (UsersController * 2) + (UserPolicy * 2) + (Post * 1) + (Comment * 1) = 3 + 2 + 2 + 1 + 1 = 9
          expect(result[:score]).to eq(9)
          expect(result[:risk_level]).to eq(:medium)
          expect(result[:direct_impact][:models]).to match_array(['Profile'])
          expect(result[:direct_impact][:controllers]).to eq(['UsersController'])
          expect(result[:direct_impact][:policies]).to eq(['UserPolicy'])
          expect(result[:indirect_impact][:models]).to match_array(['Post', 'Comment'])
        end
      end
    
      context 'with circular dependencies in the graph' do
        it 'handles cycles without infinite loops' do
          context = { related_models: [], primary_controller: nil, primary_policy: nil }
          # Graph: User -> Post -> User
          post_node = { model: 'Post', associations: { belongs_to: [], has_many: [], has_one: [] } }
          user_node = {
            model: 'User',
            associations: {
              belongs_to: [],
              has_many: [post_node],
              has_one: []
            }
          }
          post_node[:associations][:belongs_to] << user_node # Cycle
  
          allow(context_builder).to receive(:build).with('User').and_return(context)
          allow(graph_builder).to receive(:build).with('User').and_return(user_node)
  
          result = analyzer.analyze('User')
  
          expect(result[:score]).to eq(1) # Only Post is indirect
          expect(result[:risk_level]).to eq(:low)
          expect(result[:indirect_impact][:models]).to eq(['Post'])
        end
      end

      context 'when a model is both a direct and indirect dependency' do
        it 'only lists the model as a direct impact' do
            context = {
                related_models: ['/fake/project/app/models/post.rb'], # Post is direct
                primary_controller: nil,
                primary_policy: nil
              }
              # Graph: User -> Post
              graph = {
                model: 'User',
                associations: {
                  belongs_to: [],
                  has_many: [
                    { model: 'Post', associations: { belongs_to: [], has_many: [], has_one: [] } }
                  ],
                  has_one: []
                }
              }
      
              allow(context_builder).to receive(:build).with('User').and_return(context)
              allow(graph_builder).to receive(:build).with('User').and_return(graph)
      
              result = analyzer.analyze('User')
      
              expect(result[:score]).to eq(3) # Post is direct (3 points)
              expect(result[:direct_impact][:models]).to eq(['Post'])
              expect(result[:indirect_impact][:models]).to be_empty
        end
      end

      context 'with namespaced models' do
        it 'correctly analyzes models within a namespace' do
          context = {
            related_models: ['/fake/project/app/models/admin/role.rb'],
            primary_controller: 'Admin::UsersController',
            primary_policy: nil
          }
          # Graph: Admin::User -> AuditLog
          graph = {
            model: 'Admin::User',
            associations: {
              belongs_to: [],
              has_many: [
                { model: 'AuditLog', associations: { belongs_to: [], has_many: [], has_one: [] } }
              ],
              has_one: []
            }
          }

          allow(context_builder).to receive(:build).with('Admin::User').and_return(context)
          allow(graph_builder).to receive(:build).with('Admin::User').and_return(graph)

          result = analyzer.analyze('Admin::User')

          expect(result[:target]).to eq('Admin::User')
          # Score: (Admin::Role * 3) + (Admin::UsersController * 2) + (AuditLog * 1) = 3 + 2 + 1 = 6
          expect(result[:score]).to eq(6)
          expect(result[:risk_level]).to eq(:medium)
          expect(result[:direct_impact][:models]).to eq(['Admin::Role'])
          expect(result[:direct_impact][:controllers]).to eq(['Admin::UsersController'])
          expect(result[:indirect_impact][:models]).to eq(['AuditLog'])
        end
      end

      context 'with a complex graph with shared dependencies' do
        it 'correctly identifies all indirect impacts without duplication' do
          context = { related_models: [], primary_controller: nil, primary_policy: nil }
          # Graph: User -> Order -> Address
          #             |-> Shipment -> Address
          address_node = { model: 'Address', associations: { belongs_to: [], has_many: [], has_one: [] } }
          shipment_node = { model: 'Shipment', associations: { belongs_to: [address_node], has_many: [], has_one: [] } }
          order_node = { model: 'Order', associations: { belongs_to: [address_node], has_many: [], has_one: [] } }
          user_node = {
            model: 'User',
            associations: {
              belongs_to: [],
              has_many: [order_node, shipment_node],
              has_one: []
            }
          }

          allow(context_builder).to receive(:build).with('User').and_return(context)
          allow(graph_builder).to receive(:build).with('User').and_return(user_node)

          result = analyzer.analyze('User')

          # Score: Order (1) + Shipment (1) + Address (1) = 3
          expect(result[:score]).to eq(3)
          expect(result[:risk_level]).to eq(:low)
          expect(result[:indirect_impact][:models]).to match_array(['Order', 'Shipment', 'Address'])
        end
      end

      describe 'risk level calculation' do
        it 'returns :low for scores 0-5' do
          expect(analyzer.risk_level(0)).to eq(:low)
          expect(analyzer.risk_level(5)).to eq(:low)
        end
    
        it 'returns :medium for scores 6-15' do
          expect(analyzer.risk_level(6)).to eq(:medium)
          expect(analyzer.risk_level(15)).to eq(:medium)
        end
    
        it 'returns :high for scores > 15' do
          expect(analyzer.risk_level(16)).to eq(:high)
          expect(analyzer.risk_level(100)).to eq(:high)
        end
      end
  end
end