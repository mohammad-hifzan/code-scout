require 'spec_helper'
require 'active_support/inflector'

require_relative '../../lib/context/context_builder'

RSpec.describe ContextBuilder do
  subject(:builder) { described_class.new(project_map, project_path) }
  let(:project_path) { '/fake/project' }

  let(:project_map) do
    {
      models: {
        'User' => {
          path: '/fake/project/app/models/user.rb',
          associations: {
            has_many: [:posts],
            belongs_to: [:account]
          }
        },
        'Post' => {
          path: '/fake/project/app/models/post.rb',
          associations: {}
        },
        'Account' => {
          path: '/fake/project/app/models/account.rb',
          associations: {}
        },
        'Person' => {
          path: '/fake/project/app/models/person.rb',
          associations: {}
        },
        'Admin::User' => {
          path: '/fake/project/app/models/admin/user.rb',
          associations: {}
        }
      },
      controllers: {
        'UsersController' => { path: '/fake/project/app/controllers/users_controller.rb' },
        'PeopleController' => { path: '/fake/project/app/controllers/people_controller.rb' },
        'Admin::UsersController' => { path: '/fake/project/app/controllers/admin/users_controller.rb' }
      }
    }
  end

  let(:user_policy_path) { '/fake/project/app/policies/user_policy.rb' }
  let(:admin_user_policy_path) { '/fake/project/app/policies/admin/user_policy.rb' }

  before do
    # Mock filesystem interactions
    allow(File).to receive(:exist?).and_return(false) # Default to not found
    allow(Dir).to receive(:glob).and_return([]) # Default to no views unless specifically mocked
  end

  describe '#build' do
    context 'when the model does not exist' do
      it 'returns nil' do
        expect(builder.build('NonExistentModel')).to be_nil
      end
    end

    context 'when the model exists' do
      context 'with a complete set of related files' do
        let(:user_views) do
          [
            '/fake/project/app/views/users/index.html.erb',
            '/fake/project/app/views/users/_form.html.erb',
            '/fake/project/app/views/users/show.html.erb',
            '/fake/project/app/views/users/new.html.erb'
          ]
        end

        before do
          allow(File).to receive(:exist?).with(user_policy_path).and_return(true)
          allow(Dir).to receive(:glob).with('/fake/project/app/views/users/**/*.erb').and_return(user_views)
        end

        it 'returns a context hash with all related file paths' do
          context = builder.build('User')

          expect(context[:model]).to eq('/fake/project/app/models/user.rb')
          expect(context[:primary_controller]).to eq('/fake/project/app/controllers/users_controller.rb')
          expect(context[:primary_policy]).to eq(user_policy_path)
        end

        it 'identifies related models from associations' do
          context = builder.build('User')
          expect(context[:related_models]).to contain_exactly(
            '/fake/project/app/models/post.rb',
            '/fake/project/app/models/account.rb'
          )
        end

        it 'identifies primary views from the model\'s conventional directory' do
          context = builder.build('User')
          expect(context[:primary_views]).to contain_exactly(
            '/fake/project/app/views/users/index.html.erb',
            '/fake/project/app/views/users/_form.html.erb',
            '/fake/project/app/views/users/show.html.erb',
            '/fake/project/app/views/users/new.html.erb'
          )
        end
      end

      context 'with missing related files' do
        it 'returns nil for a missing controller' do
          # The map has no 'PostsController'
          context = builder.build('Post')
          expect(context[:primary_controller]).to be_nil
        end

        it 'returns nil for a missing policy' do
          # File.exist? defaults to false
          context = builder.build('User')
          expect(context[:primary_policy]).to be_nil
        end

        it 'returns an empty array for a model with no associations' do
          context = builder.build('Post')
          expect(context[:related_models]).to be_empty
        end

        it 'returns an empty array when no views match for the model\'s directory' do
          allow(Dir).to receive(:glob).with('/fake/project/app/views/accounts/**/*.erb').and_return([])
          context = builder.build('Account')
          expect(context[:primary_views]).to be_empty
        end
      end

      context 'with irregular pluralization' do
        it 'finds the correct primary controller' do
          # "Person" -> "PeopleController"
          context = builder.build('Person')
          expect(context[:primary_controller]).to eq('/fake/project/app/controllers/people_controller.rb')
        end
      end

      context 'for primary_views logic details' do
        let(:user_directory_views) do
          [
            '/fake/project/app/views/users/index.html.erb',
            '/fake/project/app/views/users/custom_report.html.erb',
            '/fake/project/app/views/users/subfolder/_partial.html.erb'
          ]
        end
        let(:shared_views) do
          ['/fake/project/app/views/shared/_user_card.html.erb']
        end

        before do
          allow(Dir).to receive(:glob).with('/fake/project/app/views/users/**/*.erb').and_return(user_directory_views)
          # Ensure globs for other directories (like shared) return nothing if not explicitly mocked
          allow(Dir).to receive(:glob).with('/fake/project/app/views/shared/**/*.erb').and_return(shared_views)
        end

        it 'finds all .erb files within the model\'s conventional view directory' do
          context = builder.build('User')
          expect(context[:primary_views]).to contain_exactly(
            '/fake/project/app/views/users/index.html.erb',
            '/fake/project/app/views/users/custom_report.html.erb',
            '/fake/project/app/views/users/subfolder/_partial.html.erb'
          )
        end

        it 'does NOT find views outside the model\'s conventional directory (e.g., shared views)' do
          context = builder.build('User')
          expect(context[:primary_views]).not_to include(
            '/fake/project/app/views/shared/_user_card.html.erb'
          )
        end
      end

      context 'with namespaced models' do
        let(:admin_user_views) do
          [
            '/fake/project/app/views/admin/users/index.html.erb',
            '/fake/project/app/views/admin/users/_form.html.erb'
          ]
        end

        before do
          allow(File).to receive(:exist?).with(admin_user_policy_path).and_return(true)
          allow(Dir).to receive(:glob).with('/fake/project/app/views/admin/users/**/*.erb').and_return(admin_user_views)
        end

        it 'finds the correct namespaced controller' do
          context = builder.build('Admin::User')
          expect(context[:primary_controller]).to eq('/fake/project/app/controllers/admin/users_controller.rb')
        end

        it 'finds the correct namespaced policy' do
          context = builder.build('Admin::User')
          expect(context[:primary_policy]).to eq(admin_user_policy_path)
        end

        it 'finds views in the namespaced model\'s conventional directory' do
          context = builder.build('Admin::User')
          expect(context[:primary_views]).to contain_exactly(
            '/fake/project/app/views/admin/users/index.html.erb',
            '/fake/project/app/views/admin/users/_form.html.erb'
          )
        end
      end

      context 'with serialization and representation artifacts' do
        let(:user_serializer_path) { '/fake/project/app/serializers/user_serializer.rb' }
        let(:post_serializer_path) { '/fake/project/app/serializers/post_serializer.rb' }
        let(:user_jbuilder_path) { '/fake/project/app/views/users/show.json.jbuilder' }
        let(:user_presenter_path) { '/fake/project/app/presenters/user_presenter.rb' }

        before do
          allow(File).to receive(:exist?).with(user_serializer_path).and_return(true)
          allow(File).to receive(:exist?).with(post_serializer_path).and_return(true)
          allow(File).to receive(:exist?).with(user_presenter_path).and_return(true)
          allow(Dir).to receive(:glob).with('/fake/project/app/views/users/**/*.jbuilder').and_return([user_jbuilder_path])
        end

        it 'discovers primary and associated serializers separately' do
          context = builder.build('User')
          expect(context[:serializers]).to contain_exactly(
            user_serializer_path,
            post_serializer_path
          )
        end

        it 'discovers json views separately' do
          context = builder.build('User')
          expect(context[:json_views]).to contain_exactly(user_jbuilder_path)
        end

        it 'discovers presenters separately' do
          context = builder.build('User')
          expect(context[:presenters]).to contain_exactly(user_presenter_path)
        end

        it 'returns empty arrays when no serializers, json views, or presenters exist' do
          context = builder.build('Person')
          expect(context[:serializers]).to be_empty
          expect(context[:json_views]).to be_empty
          expect(context[:presenters]).to be_empty
        end

        context 'with reference-derived candidate expansion' do
          let(:summary_serializer_path) { '/fake/project/app/serializers/api/v2/user_summary_serializer.rb' }
          let(:card_presenter_path) { '/fake/project/app/presenters/user_card_presenter.rb' }

          it 'expands serializers with non-conventional reference candidates and deduplicates' do
            references = [
              summary_serializer_path,
              user_serializer_path # duplicate of conventional
            ]

            context = builder.build('User', references: references)
            expect(context[:serializers]).to contain_exactly(
              user_serializer_path,
              post_serializer_path,
              summary_serializer_path
            )
          end

          it 'expands presenters with reference candidates' do
            references = [card_presenter_path]

            context = builder.build('User', references: references)
            expect(context[:presenters]).to contain_exactly(
              user_presenter_path,
              card_presenter_path
            )
          end

          it 'isolates unrelated reference categories so they do not pollute serializers or presenters' do
            references = [
              '/fake/project/app/services/user_service.rb',
              '/fake/project/app/jobs/user_job.rb',
              '/fake/project/app/mailers/user_mailer.rb',
              '/fake/project/app/policies/other_policy.rb'
            ]

            context = builder.build('User', references: references)
            expect(context[:serializers]).to contain_exactly(
              user_serializer_path,
              post_serializer_path
            )
            expect(context[:presenters]).to contain_exactly(user_presenter_path)
          end

          it 'does not discover unrelated model serializers or presenters merely because they exist' do
            order_serializer = '/fake/project/app/serializers/order_serializer.rb'
            order_presenter = '/fake/project/app/presenters/order_presenter.rb'
            allow(File).to receive(:exist?).with(order_serializer).and_return(true)
            allow(File).to receive(:exist?).with(order_presenter).and_return(true)

            context = builder.build('User')
            expect(context[:serializers]).not_to include(order_serializer)
            expect(context[:presenters]).not_to include(order_presenter)
          end
        end
      end

      context 'with background execution artifacts (jobs and workers)' do
        let(:user_job_path) { '/fake/project/app/jobs/user_job.rb' }
        let(:user_worker_path) { '/fake/project/app/workers/user_worker.rb' }
        let(:admin_user_job_path) { '/fake/project/app/jobs/admin/user_job.rb' }
        let(:admin_user_worker_path) { '/fake/project/app/workers/admin/user_worker.rb' }

        it 'discovers conventional ActiveJob file' do
          allow(File).to receive(:exist?).with(user_job_path).and_return(true)

          context = builder.build('User')
          expect(context[:jobs]).to contain_exactly(user_job_path)
        end

        it 'discovers conventional Worker file' do
          allow(File).to receive(:exist?).with(user_worker_path).and_return(true)

          context = builder.build('User')
          expect(context[:jobs]).to contain_exactly(user_worker_path)
        end

        it 'discovers both ActiveJob and Worker files when both exist' do
          allow(File).to receive(:exist?).with(user_job_path).and_return(true)
          allow(File).to receive(:exist?).with(user_worker_path).and_return(true)

          context = builder.build('User')
          expect(context[:jobs]).to contain_exactly(user_job_path, user_worker_path)
        end

        it 'discovers namespaced jobs and workers' do
          allow(File).to receive(:exist?).with(admin_user_job_path).and_return(true)
          allow(File).to receive(:exist?).with(admin_user_worker_path).and_return(true)

          context = builder.build('Admin::User')
          expect(context[:jobs]).to contain_exactly(admin_user_job_path, admin_user_worker_path)
        end

        it 'returns an empty array when no job or worker exists' do
          context = builder.build('Person')
          expect(context[:jobs]).to be_empty
        end

        context 'with reference-derived job expansion' do
          let(:custom_job_path) { '/fake/project/app/jobs/user_sync_job.rb' }
          let(:custom_worker_path) { '/fake/project/app/workers/user_export_worker.rb' }

          it 'expands jobs with reference candidates and deduplicates' do
            allow(File).to receive(:exist?).with(user_job_path).and_return(true)
            references = [
              custom_job_path,
              custom_worker_path,
              user_job_path # duplicate of conventional
            ]

            context = builder.build('User', references: references)
            expect(context[:jobs]).to contain_exactly(
              user_job_path,
              custom_job_path,
              custom_worker_path
            )
          end

          it 'isolates unrelated reference categories so they do not pollute jobs' do
            references = [
              '/fake/project/app/services/user_service.rb',
              '/fake/project/app/serializers/user_serializer.rb',
              '/fake/project/app/mailers/user_mailer.rb',
              '/fake/project/app/policies/other_policy.rb'
            ]

            context = builder.build('User', references: references)
            expect(context[:jobs]).to be_empty
          end

          it 'does not discover unrelated model jobs merely because they exist' do
            order_job = '/fake/project/app/jobs/order_job.rb'
            billing_worker = '/fake/project/app/workers/billing_worker.rb'
            allow(File).to receive(:exist?).with(order_job).and_return(true)
            allow(File).to receive(:exist?).with(billing_worker).and_return(true)

            context = builder.build('User')
            expect(context[:jobs]).not_to include(order_job)
            expect(context[:jobs]).not_to include(billing_worker)
          end
        end
      end

      context 'with mailer and email template artifacts' do
        let(:user_mailer_path) { '/fake/project/app/mailers/user_mailer.rb' }
        let(:user_mailer_views) do
          [
            '/fake/project/app/views/user_mailer/welcome.html.erb',
            '/fake/project/app/views/user_mailer/reset_password.text.erb'
          ]
        end
        let(:admin_user_mailer_path) { '/fake/project/app/mailers/admin/user_mailer.rb' }
        let(:admin_user_mailer_views) do
          [
            '/fake/project/app/views/admin/user_mailer/welcome.html.erb'
          ]
        end

        it 'discovers conventional ActionMailer file' do
          allow(File).to receive(:exist?).with(user_mailer_path).and_return(true)

          context = builder.build('User')
          expect(context[:mailers]).to contain_exactly(user_mailer_path)
          expect(context[:mailer_views]).to be_empty
        end

        it 'discovers mailer views in conventional directory' do
          allow(Dir).to receive(:glob).with('/fake/project/app/views/user_mailer/**/*').and_return(user_mailer_views)
          allow(File).to receive(:file?).and_return(true)

          context = builder.build('User')
          expect(context[:mailers]).to be_empty
          expect(context[:mailer_views]).to contain_exactly(
            '/fake/project/app/views/user_mailer/welcome.html.erb',
            '/fake/project/app/views/user_mailer/reset_password.text.erb'
          )
        end

        it 'discovers both mailer and mailer views when both exist' do
          allow(File).to receive(:exist?).with(user_mailer_path).and_return(true)
          allow(Dir).to receive(:glob).with('/fake/project/app/views/user_mailer/**/*').and_return(user_mailer_views)
          allow(File).to receive(:file?).and_return(true)

          context = builder.build('User')
          expect(context[:mailers]).to contain_exactly(user_mailer_path)
          expect(context[:mailer_views]).to contain_exactly(
            '/fake/project/app/views/user_mailer/welcome.html.erb',
            '/fake/project/app/views/user_mailer/reset_password.text.erb'
          )
        end

        it 'discovers namespaced mailer and mailer views and isolates from root user mailers' do
          allow(File).to receive(:exist?).with(admin_user_mailer_path).and_return(true)
          allow(File).to receive(:exist?).with(user_mailer_path).and_return(true)
          allow(Dir).to receive(:glob).with('/fake/project/app/views/admin/user_mailer/**/*').and_return(admin_user_mailer_views)
          allow(Dir).to receive(:glob).with('/fake/project/app/views/user_mailer/**/*').and_return(user_mailer_views)
          allow(File).to receive(:file?).and_return(true)

          context = builder.build('Admin::User')
          expect(context[:mailers]).to contain_exactly(admin_user_mailer_path)
          expect(context[:mailer_views]).to contain_exactly(
            '/fake/project/app/views/admin/user_mailer/welcome.html.erb'
          )
          expect(context[:mailers]).not_to include(user_mailer_path)
          expect(context[:mailer_views]).not_to include('/fake/project/app/views/user_mailer/welcome.html.erb')
        end

        it 'returns empty arrays when no mailer or mailer views exist' do
          context = builder.build('Person')
          expect(context[:mailers]).to be_empty
          expect(context[:mailer_views]).to be_empty
        end

        context 'with reference-derived mailer expansion' do
          let(:custom_mailer_path) { '/fake/project/app/mailers/user_notification_mailer.rb' }

          it 'expands mailers with reference candidates and deduplicates' do
            allow(File).to receive(:exist?).with(user_mailer_path).and_return(true)
            references = [
              custom_mailer_path,
              user_mailer_path # duplicate of conventional
            ]

            context = builder.build('User', references: references)
            expect(context[:mailers]).to contain_exactly(
              user_mailer_path,
              custom_mailer_path
            )
          end

          it 'isolates unrelated reference categories so they do not pollute mailers' do
            references = [
              '/fake/project/app/services/user_service.rb',
              '/fake/project/app/serializers/user_serializer.rb',
              '/fake/project/app/jobs/user_job.rb',
              '/fake/project/app/policies/other_policy.rb'
            ]

            context = builder.build('User', references: references)
            expect(context[:mailers]).to be_empty
          end

          it 'does not discover unrelated model mailers merely because they exist' do
            order_mailer = '/fake/project/app/mailers/order_mailer.rb'
            billing_mailer = '/fake/project/app/mailers/billing_mailer.rb'
            allow(File).to receive(:exist?).with(order_mailer).and_return(true)
            allow(File).to receive(:exist?).with(billing_mailer).and_return(true)

            context = builder.build('User')
            expect(context[:mailers]).not_to include(order_mailer)
            expect(context[:mailers]).not_to include(billing_mailer)
          end
        end
      end

      context 'with model concerns and mixins' do
        let(:user_model_path) { '/fake/project/app/models/user.rb' }
        let(:admin_user_model_path) { '/fake/project/app/models/admin/user.rb' }
        let(:auditable_concern_path) { '/fake/project/app/models/concerns/auditable.rb' }
        let(:searchable_concern_path) { '/fake/project/app/models/concerns/searchable.rb' }
        let(:foo_bar_concern_path) { '/fake/project/app/models/concerns/foo/bar.rb' }
        let(:admin_auditable_concern_path) { '/fake/project/app/models/concerns/admin/auditable.rb' }
        let(:archivable_concern_path) { '/fake/project/app/models/concerns/archivable.rb' }

        before do
          allow(File).to receive(:exist?).with(user_model_path).and_return(true)
          allow(File).to receive(:exist?).with(admin_user_model_path).and_return(true)
        end

        it 'discovers a simple concern from AST include' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  include Auditable\nend")
          allow(File).to receive(:exist?).with(auditable_concern_path).and_return(true)

          context = builder.build('User')
          expect(context[:concerns]).to contain_exactly(auditable_concern_path)
        end

        it 'discovers multiple separate AST include declarations' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  include Auditable\n  include Searchable\nend")
          allow(File).to receive(:exist?).with(auditable_concern_path).and_return(true)
          allow(File).to receive(:exist?).with(searchable_concern_path).and_return(true)

          context = builder.build('User')
          expect(context[:concerns]).to contain_exactly(auditable_concern_path, searchable_concern_path)
        end

        it 'discovers namespaced concerns from AST include' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  include Foo::Bar\nend")
          allow(File).to receive(:exist?).with(foo_bar_concern_path).and_return(true)

          context = builder.build('User')
          expect(context[:concerns]).to contain_exactly(foo_bar_concern_path)
        end

        it 'discovers namespaced concerns for namespaced models' do
          allow(File).to receive(:read).with(admin_user_model_path).and_return("class Admin::User < ApplicationRecord\n  include Admin::Auditable\nend")
          allow(File).to receive(:exist?).with(admin_auditable_concern_path).and_return(true)

          context = builder.build('Admin::User')
          expect(context[:concerns]).to contain_exactly(admin_auditable_concern_path)
        end

        it 'discovers concerns from AST extend' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  extend Archivable\nend")
          allow(File).to receive(:exist?).with(archivable_concern_path).and_return(true)

          context = builder.build('User')
          expect(context[:concerns]).to contain_exactly(archivable_concern_path)
        end

        it 'silently omits concerns when the resolved concern file does not exist on disk' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  include MissingConcern\nend")
          # File.exist? defaults to false

          context = builder.build('User')
          expect(context[:concerns]).to be_empty
        end

        it 'silently omits external framework/gem mixins that do not live in app/models/concerns' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  include Enumerable\n  include ActiveModel::Validations\nend")

          context = builder.build('User')
          expect(context[:concerns]).to be_empty
        end

        it 'safely fails closed on dynamic include expressions' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  include const_get(name)\nend")

          context = builder.build('User')
          expect(context[:concerns]).to be_empty
        end

        it 'discovers reference-derived model concerns' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\nend")
          custom_concern = '/fake/project/app/models/concerns/user_tracking.rb'
          allow(File).to receive(:exist?).with(custom_concern).and_return(true)

          references = [custom_concern]
          context = builder.build('User', references: references)
          expect(context[:concerns]).to contain_exactly(custom_concern)
        end

        it 'strictly excludes controller concerns from model context' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\nend")
          controller_concern = '/fake/project/app/controllers/concerns/authenticatable.rb'
          allow(File).to receive(:exist?).with(controller_concern).and_return(true)

          references = [controller_concern]
          context = builder.build('User', references: references)
          expect(context[:concerns]).to be_empty
        end

        it 'merges AST-derived and reference-derived concerns and deduplicates' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  include Auditable\nend")
          allow(File).to receive(:exist?).with(auditable_concern_path).and_return(true)
          custom_concern = '/fake/project/app/models/concerns/user_tracking.rb'
          allow(File).to receive(:exist?).with(custom_concern).and_return(true)

          references = [
            auditable_concern_path, # duplicate of AST
            custom_concern
          ]
          context = builder.build('User', references: references)
          expect(context[:concerns]).to contain_exactly(
            auditable_concern_path,
            custom_concern
          )
        end

        it 'isolates unrelated reference categories so they do not pollute concerns' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\nend")
          references = [
            '/fake/project/app/services/user_service.rb',
            '/fake/project/app/serializers/user_serializer.rb',
            '/fake/project/app/jobs/user_job.rb',
            '/fake/project/app/mailers/user_mailer.rb',
            '/fake/project/app/policies/other_policy.rb'
          ]

          context = builder.build('User', references: references)
          expect(context[:concerns]).to be_empty
        end

        it 'returns empty array when model exists but has no concerns' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\nend")

          context = builder.build('User')
          expect(context[:concerns]).to be_empty
        end

        it 'does not perform broad repository scanning when references are not supplied' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\nend")
          unrelated_concern = '/fake/project/app/models/concerns/unrelated.rb'
          allow(File).to receive(:exist?).with(unrelated_concern).and_return(true)

          context = builder.build('User')
          expect(context[:concerns]).to be_empty
        end
      end

      context 'with custom validators' do
        let(:user_model_path) { '/fake/project/app/models/user.rb' }
        let(:admin_user_model_path) { '/fake/project/app/models/admin/user.rb' }
        let(:email_domain_validator_path) { '/fake/project/app/validators/email_domain_validator.rb' }
        let(:some_validator_path) { '/fake/project/app/validators/some_validator.rb' }
        let(:admin_some_validator_path) { '/fake/project/app/validators/admin/some_validator.rb' }

        before do
          allow(File).to receive(:exist?).with(user_model_path).and_return(true)
          allow(File).to receive(:exist?).with(admin_user_model_path).and_return(true)
        end

        it 'discovers a custom validator from AST validates with custom option' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  validates :email, email_domain: true\nend")
          allow(File).to receive(:exist?).with(email_domain_validator_path).and_return(true)

          context = builder.build('User')
          expect(context[:validators]).to contain_exactly(email_domain_validator_path)
        end

        it 'discovers a validator from AST validates_with' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  validates_with SomeValidator\nend")
          allow(File).to receive(:exist?).with(some_validator_path).and_return(true)

          context = builder.build('User')
          expect(context[:validators]).to contain_exactly(some_validator_path)
        end

        it 'discovers namespaced validator from AST validates_with' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  validates_with Admin::SomeValidator\nend")
          allow(File).to receive(:exist?).with(admin_some_validator_path).and_return(true)

          context = builder.build('User')
          expect(context[:validators]).to contain_exactly(admin_some_validator_path)
        end

        it 'silently omits validators when the resolved file does not exist on disk' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  validates_with MissingValidator\nend")

          context = builder.build('User')
          expect(context[:validators]).to be_empty
        end

        it 'strictly excludes validator files located outside app/validators/' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  validates_with ExternalValidator\nend")
          lib_validator = '/fake/project/lib/validators/external_validator.rb'
          allow(File).to receive(:exist?).with(lib_validator).and_return(true)

          context = builder.build('User')
          expect(context[:validators]).to be_empty
        end

        it 'strictly rejects validation keys attempting path traversal outside app/validators/' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  validates :email, \"../../lib/evil\": true\nend")
          evil_path = File.expand_path('/fake/project/lib/evil_validator.rb')
          allow(File).to receive(:exist?).with(evil_path).and_return(true)

          context = builder.build('User')
          expect(context[:validators]).to be_empty

          # Also test hash-rocket syntax
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  validates :email, :\"../../lib/evil\" => true\nend")
          context_rocket = builder.build('User')
          expect(context_rocket[:validators]).to be_empty
        end

        it 'discovers namespaced validator from AST validates_with for Admin::EmailDomainValidator' do
          admin_email_domain_validator_path = '/fake/project/app/validators/admin/email_domain_validator.rb'
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  validates_with Admin::EmailDomainValidator\nend")
          allow(File).to receive(:exist?).with(admin_email_domain_validator_path).and_return(true)

          context = builder.build('User')
          expect(context[:validators]).to contain_exactly(admin_email_domain_validator_path)
        end

        it 'does not discover built-in validation options as validator files' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  validates :email, presence: true, uniqueness: true\nend")
          presence_validator = '/fake/project/app/validators/presence_validator.rb'
          allow(File).to receive(:exist?).with(presence_validator).and_return(true)

          context = builder.build('User')
          expect(context[:validators]).to be_empty
        end

        it 'deduplicates multiple references to the same validator' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\n  validates :email, email_domain: true\n  validates :backup_email, email_domain: true\nend")
          allow(File).to receive(:exist?).with(email_domain_validator_path).and_return(true)

          context = builder.build('User')
          expect(context[:validators]).to contain_exactly(email_domain_validator_path)
        end

        it 'returns empty array when model exists but has no validators' do
          allow(File).to receive(:read).with(user_model_path).and_return("class User < ApplicationRecord\nend")

          context = builder.build('User')
          expect(context[:validators]).to be_empty
        end
      end
    end
  end

  # Test cases for the private method `related_models`
  describe '#related_models' do
    let(:project_map) do
      {
        models: {
          'User' => {
            path: '/fake/project/app/models/user.rb',
            associations: { has_many: [:posts], belongs_to: [:account] }
          },
          'Post' => { path: '/fake/project/app/models/post.rb', associations: {} },
          'Account' => { path: '/fake/project/app/models/account.rb', associations: {} },
          'Comment' => {
            path: '/fake/project/app/models/comment.rb',
            associations: {
              has_many: [:likes], # 'Like' model does not exist
              belongs_to: [:user],
              has_one: [:attachment]
            }
          },
          'Attachment' => { path: '/fake/project/app/models/attachment.rb', associations: {} },
          'Media' => { path: '/fake/project/app/models/media.rb', associations: {} }, # Irregular plural
          'Content' => {
            path: '/fake/project/app/models/content.rb',
            associations: { has_many: [:media] }
          }
        }
      }
    end

    it 'resolves `has_many` associations to existing models' do
      related = builder.send(:related_models, project_map[:models]['User'])
      expect(related).to include('/fake/project/app/models/post.rb')
    end

    it 'resolves `belongs_to` associations to existing models' do
      related = builder.send(:related_models, project_map[:models]['User'])
      expect(related).to include('/fake/project/app/models/account.rb')
    end

    it 'returns all related model paths from multiple association types' do
      related = builder.send(:related_models, project_map[:models]['Comment'])
      expect(related).to contain_exactly(
        '/fake/project/app/models/user.rb',
        '/fake/project/app/models/attachment.rb'
      )
    end

    it 'ignores associations where the derived model does not exist in the project map' do
      related = builder.send(:related_models, project_map[:models]['Comment'])
      # 'likes' -> 'Like', which is not in the map
      expect(related).not_to include(a_string_ending_with('like.rb'))
    end

    it 'returns an empty array for a model with no associations' do
      related = builder.send(:related_models, project_map[:models]['Post'])
      expect(related).to be_empty
    end

    context 'with structured association metadata' do
      let(:project_map) do
        {
          models: {
            'Order' => {
              path: '/fake/project/app/models/order.rb',
              associations: {
                has_many: [
                  { name: 'items', class_name: 'OrderItem' },
                  { name: 'commenters', through: 'comments', source: 'user' }
                ],
                belongs_to: [
                  { name: 'author', class_name: 'Admin::User' }
                ]
              }
            },
            'OrderItem' => { path: '/fake/project/app/models/order_item.rb', associations: {} },
            'Admin::User' => { path: '/fake/project/app/models/admin/user.rb', associations: {} },
            'User' => { path: '/fake/project/app/models/user.rb', associations: {} }
          }
        }
      end

      it 'resolves explicit class_name targets for has_many and belongs_to' do
        related = builder.send(:related_models, project_map[:models]['Order'])
        expect(related).to include('/fake/project/app/models/order_item.rb')
        expect(related).to include('/fake/project/app/models/admin/user.rb')
      end

      it 'does not treat source option as a direct dependency for through/source associations' do
        related = builder.send(:related_models, project_map[:models]['Order'])
        expect(related).not_to include('/fake/project/app/models/user.rb')
      end

      it 'resolves the intermediate through model as a direct dependency when present' do
        map = {
          models: {
            'Post' => {
              path: '/fake/project/app/models/post.rb',
              associations: {
                has_many: [{ name: 'tags', through: 'taggings' }]
              }
            },
            'Tagging' => { path: '/fake/project/app/models/tagging.rb', associations: {} },
            'Tag' => { path: '/fake/project/app/models/tag.rb', associations: {} }
          }
        }
        test_builder = described_class.new(map, '/fake/project')
        related = test_builder.send(:related_models, map[:models]['Post'])
        expect(related).to contain_exactly('/fake/project/app/models/tagging.rb')
      end

      context 'with namespaced model resolving relative association' do
        let(:project_map) do
          {
            models: {
              'Billing::Invoice' => {
                path: '/fake/project/app/models/billing/invoice.rb',
                associations: {
                  belongs_to: [{ name: 'customer' }]
                }
              },
              'Billing::Customer' => {
                path: '/fake/project/app/models/billing/customer.rb',
                associations: {}
              }
            },
            controllers: {}
          }
        end

        it 'resolves the association relative to the model namespace' do
          context = builder.build('Billing::Invoice')
          expect(context[:related_models]).to contain_exactly(
            '/fake/project/app/models/billing/customer.rb'
          )
        end
      end
    end

    context 'with polymorphic associations' do
      let(:project_map) do
        {
          models: {
            'Picture' => {
              path: '/fake/project/app/models/picture.rb',
              associations: {
                belongs_to: [{ name: 'imageable', polymorphic: true }]
              }
            },
            'Post' => {
              path: '/fake/project/app/models/post.rb',
              associations: {
                has_many: [{ name: 'pictures', as: 'imageable' }]
              }
            },
            'MixedModel' => {
              path: '/fake/project/app/models/mixed_model.rb',
              associations: {
                belongs_to: [{ name: 'imageable', polymorphic: true }],
                has_many: [{ name: 'posts' }]
              }
            },
            'Imageable' => {
              path: '/fake/project/app/models/imageable.rb',
              associations: {}
            }
          },
          controllers: {}
        }
      end

      it 'does not treat polymorphic belongs_to interface as a related model' do
        context = builder.build('Picture')
        expect(context[:related_models]).to be_empty
        expect(context[:related_models]).not_to include('/fake/project/app/models/imageable.rb')
      end

      it 'does not resolve to Imageable model even when Imageable exists in the project map' do
        related = builder.send(:related_models, project_map[:models]['Picture'], 'Picture')
        expect(related).to be_empty
      end

      it 'resolves the target model for has_many with as: option normally' do
        context = builder.build('Post')
        expect(context[:related_models]).to contain_exactly('/fake/project/app/models/picture.rb')
      end

      it 'resolves concrete associations while ignoring polymorphic ones in mixed models' do
        context = builder.build('MixedModel')
        expect(context[:related_models]).to contain_exactly('/fake/project/app/models/post.rb')
      end
    end

    context 'with irregular plurals' do
      it 'fails to find the model if the singularization is incorrect' do
        # The current implementation does: :media -> "media" -> singularize -> "medium" -> camelize -> "Medium"
        # It looks for a "Medium" model, which does not exist in our map.
        # This test confirms that it does NOT find the "Media" model.
        related = builder.send(:related_models, project_map[:models]['Content'])
        expect(related).to be_empty
        expect(related).not_to include('/fake/project/app/models/media.rb')
      end
    end
  end
end
