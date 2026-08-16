require 'spec_helper'
require_relative '../lib/dependency_resolver'
require_relative '../lib/context/context_builder'

RSpec.describe DependencyResolver do
  # These are needed for the constructor of DependencyResolver, but their
  # values are passed to the mocked ContextBuilder.
  let(:project_map) { { a: 1 } }
  let(:project_path) { '/fake/project' }
  let(:model_name) { 'MyModel' }

  # We are testing DependencyResolver in isolation. Its main collaborator is
  # ContextBuilder, which we will mock to provide controlled input.
  let(:context_builder_double) { instance_double(ContextBuilder) }
  
  subject(:resolver) { described_class.new(project_map, project_path) }

  before do
    # Ensure that any call to ContextBuilder.new returns our mock, allowing us
    # to control its output via `allow(context_builder_double).to receive(...)`
    allow(ContextBuilder).to receive(:new).with(project_map, project_path).and_return(context_builder_double)
  end

  describe '#build' do
    context 'with namespaced dependencies (regression test)' do
      it 'preserves namespaces when converting file paths to class names' do
        # Arrange: Simulate ContextBuilder finding paths to namespaced files.
        context_from_builder = {
          related_models: ["#{project_path}/app/models/admin/audit_log.rb"],
          primary_controller: "#{project_path}/app/controllers/api/v1/users_controller.rb",
          primary_policy: "#{project_path}/app/policies/reporting/dashboard_policy.rb"
        }
        allow(context_builder_double).to receive(:build).with(model_name).and_return(context_from_builder)

        # Act: Run the resolver, which contains the buggy implementation.
        result = resolver.build(model_name)

        # Assert: Check for the CORRECT, namespaced class names.
        # This assertion is expected to FAIL against the current implementation,
        # thus proving the bug.
        expect(result).to eq({
          models: ['Admin::AuditLog'],
          controllers: ['Api::V1::UsersController'],
          policies: ['Reporting::DashboardPolicy']
        })
      end
    end

    it 'returns nil if the context builder returns nil' do
      allow(context_builder_double).to receive(:build).with(model_name).and_return(nil)
      expect(resolver.build(model_name)).to be_nil
    end

    it 'handles empty and nil values from the context hash' do
      context_from_builder = {
        related_models: [],
        primary_controller: nil,
        primary_policy: [] 
      }
      allow(context_builder_double).to receive(:build).with(model_name).and_return(context_from_builder)

      result = resolver.build(model_name)

      expect(result).to eq({ models: [], controllers: [], policies: [] })
    end
  end
end
