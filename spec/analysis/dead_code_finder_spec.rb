# frozen_string_literal: true

require 'spec_helper'
require 'analysis/dead_code_finder'
require 'model_usage_finder'
require 'controller_usage_finder'
require 'policy_usage_finder'
require 'analysis/inheritance_usage_finder'
require 'analysis/reference_finder'

RSpec.describe DeadCodeFinder do
  let(:project_path) { '/fake/project' }
  let(:project_map) do
    {
      models: {
        'UsedModel' => { path: '/fake/project/app/models/used_model.rb' },
        'UnusedModel' => { path: '/fake/project/app/models/unused_model.rb' },
        'InheritedModel' => { path: '/fake/project/app/models/inherited_model.rb' }
      },
      controllers: {
        'UsedController' => { path: '/fake/project/app/controllers/used_controller.rb' },
        'UnusedController' => { path: '/fake/project/app/controllers/unused_controller.rb' },
        'InheritedController' => { path: '/fake/project/app/controllers/inherited_controller.rb' }
      }
    }
  end

  let(:model_usage_finder) { instance_double('ModelUsageFinder') }
  let(:controller_usage_finder) { instance_double('ControllerUsageFinder') }
  let(:policy_usage_finder) { instance_double('PolicyUsageFinder') }
  let(:inheritance_usage_finder) { instance_double('InheritanceUsageFinder') }
  let(:reference_finder) { instance_double('ReferenceFinder') }

  before do
    allow(ModelUsageFinder).to receive(:new).and_return(model_usage_finder)
    allow(ControllerUsageFinder).to receive(:new).and_return(controller_usage_finder)
    allow(PolicyUsageFinder).to receive(:new).and_return(policy_usage_finder)
    allow(InheritanceUsageFinder).to receive(:new).and_return(inheritance_usage_finder)
    allow(ReferenceFinder).to receive(:new).and_return(reference_finder)

    # Default stubs for "used" components
    allow(model_usage_finder).to receive(:used_models).and_return(['UsedModel'])
    allow(controller_usage_finder).to receive(:used_controllers).and_return(['UsedController'])
    allow(policy_usage_finder).to receive(:used_policies).and_return(['UsedModelPolicy'])
    allow(inheritance_usage_finder).to receive(:used_classes).and_return(['InheritedModel', 'InheritedController'])

    # Stubbing Dir.glob for policies and helpers
    allow(Dir).to receive(:glob).with(File.join(project_path, "app/policies/**/*.rb")).and_return([
      '/fake/project/app/policies/used_model_policy.rb',
      '/fake/project/app/policies/unused_policy.rb',
      '/fake/project/app/policies/inherited_model_policy.rb'
    ])
    allow(Dir).to receive(:glob).with(File.join(project_path, "app/helpers/**/*.rb")).and_return([
      '/fake/project/app/helpers/used_helper.rb',
      '/fake/project/app/helpers/unused_helper.rb'
    ])

    # Stubbing ReferenceFinder
    allow(reference_finder).to receive(:find).with('UsedHelper').and_return(['/path/1', '/path/2'])
    allow(reference_finder).to receive(:find).with('UnusedHelper').and_return(['/path/1'])
  end

  subject { described_class.new(project_map, project_path) }

  describe '#find' do
    let(:result) { subject.find }

    context 'when there are unused components' do
      it 'identifies unused models' do
        expect(result[:models]).to contain_exactly('UnusedModel')
      end

      it 'identifies unused controllers' do
        expect(result[:controllers]).to contain_exactly('UnusedController')
      end

      it 'identifies unused policies' do
        allow(policy_usage_finder).to receive(:used_policies).and_return(['UsedModelPolicy'])
        allow(inheritance_usage_finder).to receive(:used_classes).and_return([])
        # Need to re-run find to get fresh results with new stubs
        fresh_result = subject.find
        expect(fresh_result[:policies]).to contain_exactly('UnusedPolicy', 'InheritedModelPolicy')
      end

      it 'identifies unused helpers' do
        expect(result[:helpers]).to contain_exactly('UnusedHelper')
      end
    end

    context 'when all components are used' do
      before do
        allow(model_usage_finder).to receive(:used_models).and_return(['UsedModel', 'UnusedModel', 'InheritedModel'])
        allow(controller_usage_finder).to receive(:used_controllers).and_return(['UsedController', 'UnusedController'])
        allow(policy_usage_finder).to receive(:used_policies).and_return(['UsedModelPolicy', 'UnusedPolicy', 'InheritedModelPolicy'])
        allow(reference_finder).to receive(:find).with('UnusedHelper').and_return(['/path/1', '/path/2'])
      end

      it 'returns no unused models' do
        expect(result[:models]).to be_empty
      end

      it 'returns no unused controllers' do
        # Still has UnusedController because it's not in the inheritance mock
        allow(inheritance_usage_finder).to receive(:used_classes).and_return(['InheritedModel', 'InheritedController','UnusedController'])
        expect(subject.find[:controllers]).to be_empty
      end

      it 'returns no unused policies' do
         allow(policy_usage_finder).to receive(:used_policies).and_return(['UsedModelPolicy', 'UnusedPolicy'])
         allow(inheritance_usage_finder).to receive(:used_classes).and_return(['InheritedModelPolicy'])
         expect(subject.find[:policies]).to be_empty
      end

      it 'returns no unused helpers' do
        expect(result[:helpers]).to be_empty
      end
    end

    context 'with empty project map' do
       let(:project_map) { { models: {}, controllers: {} } }
       before do
         allow(model_usage_finder).to receive(:used_models).and_return([])
         allow(controller_usage_finder).to receive(:used_controllers).and_return([])
         allow(policy_usage_finder).to receive(:used_policies).and_return([])
         allow(inheritance_usage_finder).to receive(:used_classes).and_return([])
         allow(Dir).to receive(:glob).with(File.join(project_path, "app/policies/**/*.rb")).and_return([])
         allow(Dir).to receive(:glob).with(File.join(project_path, "app/helpers/**/*.rb")).and_return([])
       end

       it 'returns no unused components' do
         expect(result[:models]).to be_empty
         expect(result[:controllers]).to be_empty
         expect(result[:policies]).to be_empty
         expect(result[:helpers]).to be_empty
       end
    end
    
    context 'with missing or empty usage results' do
        before do
            allow(model_usage_finder).to receive(:used_models).and_return([])
            allow(controller_usage_finder).to receive(:used_controllers).and_return([])
            allow(policy_usage_finder).to receive(:used_policies).and_return([])
            allow(inheritance_usage_finder).to receive(:used_classes).and_return([])
        end

        it 'considers all components as unused' do
            expect(result[:models]).to contain_exactly('UsedModel', 'UnusedModel', 'InheritedModel')
            expect(result[:controllers]).to contain_exactly('UsedController', 'UnusedController', 'InheritedController')
            expect(result[:policies]).to contain_exactly('UsedModelPolicy', 'UnusedPolicy', 'InheritedModelPolicy')
        end
    end

    context 'when usage is through inheritance' do
      it 'does not report inherited models as unused' do
        expect(result[:models]).not_to include('InheritedModel')
      end

      it 'does not report inherited controllers as unused' do
        expect(result[:controllers]).not_to include('InheritedController')
      end
    end
    
    context 'with duplicate references' do
      before do
        allow(model_usage_finder).to receive(:used_models).and_return(['UsedModel', 'UsedModel'])
        allow(controller_usage_finder).to receive(:used_controllers).and_return(['UsedController', 'UsedController'])
        allow(inheritance_usage_finder).to receive(:used_classes).and_return(['InheritedController', 'InheritedController'])
      end

      it 'handles duplicate usage data correctly' do
        expect(result[:controllers]).to contain_exactly('UnusedController')
      end
    end
  end
end