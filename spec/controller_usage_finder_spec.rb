require 'spec_helper'
require 'controller_usage_finder'
require 'indexing/route_mapper'

RSpec.describe ControllerUsageFinder do
  let(:project_path) { 'spec/fixtures/project' }
  subject { described_class.new(project_path) }

  describe '#used_controllers' do
    let(:route_mapper) { instance_double(RouteMapper) }

    before do
      allow(RouteMapper).to receive(:new).with(project_path).and_return(route_mapper)
    end

    context 'with normal controller usage' do
      it 'returns the used controllers' do
        routes = [
          { controller: 'UsersController', action: 'index' },
          { controller: 'PostsController', action: 'show' }
        ]
        allow(route_mapper).to receive(:map).and_return(routes)
        expect(subject.used_controllers).to contain_exactly('UsersController', 'PostsController')
      end
    end

    context 'with multiple controllers' do
      it 'returns all used controllers' do
        routes = [
          { controller: 'UsersController', action: 'index' },
          { controller: 'PostsController', action: 'show' },
          { controller: 'CommentsController', action: 'create' }
        ]
        allow(route_mapper).to receive(:map).and_return(routes)
        expect(subject.used_controllers).to contain_exactly('UsersController', 'PostsController', 'CommentsController')
      end
    end

    context 'with duplicate results' do
      it 'returns a unique list of controllers' do
        routes = [
          { controller: 'UsersController', action: 'index' },
          { controller: 'UsersController', action: 'show' },
          { controller: 'PostsController', action: 'index' }
        ]
        allow(route_mapper).to receive(:map).and_return(routes)
        expect(subject.used_controllers).to contain_exactly('UsersController', 'PostsController')
      end
    end

    context 'with namespaced controllers' do
      it 'returns the full namespaced controller name' do
        routes = [
          { controller: 'Api::V1::UsersController', action: 'index' },
          { controller: 'Admin::DashboardController', action: 'show' }
        ]
        allow(route_mapper).to receive(:map).and_return(routes)
        expect(subject.used_controllers).to contain_exactly('Api::V1::UsersController', 'Admin::DashboardController')
      end
    end

    context 'with routes that do not have a controller' do
      it 'filters out routes without a controller' do
        routes = [
          { controller: 'UsersController', action: 'index' },
          { action: 'show' }, # No controller
          { controller: nil, action: 'new' }
        ]
        allow(route_mapper).to receive(:map).and_return(routes)
        expect(subject.used_controllers).to contain_exactly('UsersController')
      end
    end

    context 'when project data is empty or missing' do
      it 'returns an empty array when route mapper returns empty' do
        allow(route_mapper).to receive(:map).and_return([])
        expect(subject.used_controllers).to be_empty
      end
    end

    context 'when route mapper returns a mix of valid and invalid data' do
      it 'handles various data shapes gracefully' do
        routes = [
          { controller: 'UsersController', action: 'index' },
          'PostsController', # Invalid data
          { controller: 'Admin::DashboardController' },
          { controller: nil },
          nil
        ]
        allow(route_mapper).to receive(:map).and_return(routes)
        # This will fail without a fix
        expect(subject.used_controllers).to contain_exactly('UsersController', 'Admin::DashboardController')
      end
    end

    context 'with missing files/directories', fakefs: true do
      it 'returns an empty array if project path does not exist' do
        # With FakeFS, the directory does not exist unless created
        non_existent_path = '/non_existent_project'
        allow(RouteMapper).to receive(:new).with(non_existent_path).and_call_original
        finder = described_class.new(non_existent_path)
        expect(finder.used_controllers).to be_empty
      end

      it 'returns an empty array if routes.rb does not exist' do
        # Create project dir but not routes.rb
        FileUtils.mkdir_p(project_path)
        allow(RouteMapper).to receive(:new).with(project_path).and_call_original
        expect(subject.used_controllers).to be_empty
      end
    end
  end
end
