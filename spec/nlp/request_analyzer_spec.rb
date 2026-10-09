require "spec_helper"

require_relative "../../lib/nlp/request_analyzer"

RSpec.describe RequestAnalyzer do
  let(:known_models) { ["Shop", "User", "Post", "Billing::Invoice"] }
  let(:analyzer) { described_class.new(models: known_models) }

  describe "#analyze" do
    it "detects edit requests" do
      expect(
        analyzer.analyze("Add slug validation to Shop")
      ).to eq(
        action: :edit,
        entity: "Shop",
        topic: :validation
      )
    end

    it "detects explain requests" do
      expect(
        analyzer.analyze("Explain Shop")
      ).to eq(
        action: :explain,
        entity: "Shop",
        topic: :general
      )
    end

    it "detects debug requests" do
      expect(
        analyzer.analyze("Debug Shop")
      ).to eq(
        action: :debug,
        entity: "Shop",
        topic: :general
      )
    end

    it "defaults to the :edit action for generic requests" do
      analysis = analyzer.analyze("some generic request")
      expect(analysis[:action]).to eq(:edit)
      expect(analysis[:entity]).to be_nil
      expect(analysis[:topic]).to eq(:general)
    end

    it "resolves entity when action is lowercase" do
      expect(
        analyzer.analyze("add a validation to User")
      ).to eq(
        action: :edit,
        entity: "User",
        topic: :validation
      )
    end

    it "resolves entity when action has trailing punctuation" do
      expect(
        analyzer.analyze("Add a validation to User.")
      ).to eq(
        action: :edit,
        entity: "User",
        topic: :validation
      )
    end

    it "does not allow 'how' to override an explicit edit request" do
      expect(
        analyzer.analyze("Change how User's posts are serialized.")
      ).to eq(
        action: :edit,
        entity: "User",
        topic: :serialization
      )
    end

    it "detects debug requests with error details and plural model" do
      expect(
        analyzer.analyze("Users are getting a NoMethodError when loading their posts. Fix it.")
      ).to eq(
        action: :debug,
        entity: "User",
        topic: :general
      )
    end

    it "detects edit requests with complex descriptions" do
      expect(
        analyzer.analyze("Change the User model's status representation.")
      ).to eq(
        action: :edit,
        entity: "User",
        topic: :general
      )
    end

    it "resolves plural model references to canonical model name" do
      expect(
        analyzer.analyze("Delete old Posts from the database")
      ).to eq(
        action: :edit,
        entity: "Post",
        topic: :general
      )
    end

    it "resolves lowercase model references" do
      expect(
        analyzer.analyze("explain user permissions")
      ).to eq(
        action: :explain,
        entity: "User",
        topic: :general
      )
    end

    it "resolves namespaced models" do
      expect(
        analyzer.analyze("Add total amount calculation to Billing::Invoice")
      ).to eq(
        action: :edit,
        entity: "Billing::Invoice",
        topic: :general
      )
    end

    it "resolves demodulized reference for namespaced model" do
      expect(
        analyzer.analyze("Update Invoice tax rates")
      ).to eq(
        action: :edit,
        entity: "Billing::Invoice",
        topic: :general
      )
    end

    it "returns nil entity when the request references an unknown model" do
      expect(
        analyzer.analyze("Add validation to Account")
      ).to eq(
        action: :edit,
        entity: nil,
        topic: :validation
      )
    end

    it "never selects action keywords as entities merely because they are capitalized" do
      expect(
        analyzer.analyze("Add validation to unknown model")
      ).to eq(
        action: :edit,
        entity: nil,
        topic: :validation
      )

      expect(
        analyzer.analyze("Explain unknown concept")
      ).to eq(
        action: :explain,
        entity: nil,
        topic: :general
      )

      expect(
        analyzer.analyze("Debug unexpected behavior")
      ).to eq(
        action: :debug,
        entity: nil,
        topic: :general
      )
    end

    it "does not resolve plural forms if the model does not exist in the project" do
      expect(
        analyzer.analyze("Change Orders status")
      ).to eq(
        action: :edit,
        entity: nil,
        topic: :general
      )
    end

    it "allows overriding models per analyze call" do
      scoped_analyzer = described_class.new(models: ["User"])
      expect(
        scoped_analyzer.analyze("Explain Shop", models: ["Shop"])
      ).to eq(
        action: :explain,
        entity: "Shop",
        topic: :general
      )
    end
  end

  describe "topic classification" do
    it "detects validation topic" do
      expect(analyzer.analyze("Add a validation to User")[:topic]).to eq(:validation)
      expect(analyzer.analyze("Add a presence validation to User")[:topic]).to eq(:validation)
      expect(analyzer.analyze("validate user email format")[:topic]).to eq(:validation)
      expect(analyzer.analyze("User model validates presence")[:topic]).to eq(:validation)
    end

    it "detects serialization topic" do
      expect(analyzer.analyze("Change how User's posts are serialized")[:topic]).to eq(:serialization)
      expect(analyzer.analyze("Change User JSON representation")[:topic]).to eq(:serialization)
      expect(analyzer.analyze("Create UserSerializer for API")[:topic]).to eq(:serialization)
      expect(analyzer.analyze("Add as_json helper to User")[:topic]).to eq(:serialization)
      expect(analyzer.analyze("Update user jbuilder view")[:topic]).to eq(:serialization)
    end

    it "detects job topic" do
      expect(analyzer.analyze("Debug failure in UserJob")[:topic]).to eq(:job)
      expect(analyzer.analyze("Fix User Sidekiq worker")[:topic]).to eq(:job)
      expect(analyzer.analyze("Add background job to process User")[:topic]).to eq(:job)
      expect(analyzer.analyze("Implement perform method for UserSync")[:topic]).to eq(:job)
    end

    it "detects mailer topic" do
      expect(analyzer.analyze("Change UserMailer")[:topic]).to eq(:mailer)
      expect(analyzer.analyze("Update UserMailer")[:topic]).to eq(:mailer)
      expect(analyzer.analyze("Why is UserMailer failing?")[:topic]).to eq(:mailer)
      expect(analyzer.analyze("Why is UserMailer not delivering?")[:topic]).to eq(:mailer)
      expect(analyzer.analyze("Update the User welcome email template")[:topic]).to eq(:mailer)
      expect(analyzer.analyze("Change the password reset email template for User")[:topic]).to eq(:mailer)
      expect(analyzer.analyze("Fix email delivery for User")[:topic]).to eq(:mailer)
      expect(analyzer.analyze("Configure deliver mail for User")[:topic]).to eq(:mailer)
    end

    it "detects service topic" do
      expect(analyzer.analyze("Create User service object")[:topic]).to eq(:service)
      expect(analyzer.analyze("Refactor UserService")[:topic]).to eq(:service)
      expect(analyzer.analyze("Add UserCreator interactor")[:topic]).to eq(:service)
      expect(analyzer.analyze("Implement UserRegistration use case")[:topic]).to eq(:service)
    end

    it "detects policy topic" do
      expect(analyzer.analyze("Change User authorization policy")[:topic]).to eq(:policy)
      expect(analyzer.analyze("Update UserPolicy")[:topic]).to eq(:policy)
      expect(analyzer.analyze("Authorize User in controller")[:topic]).to eq(:policy)
      expect(analyzer.analyze("Add Pundit check to User")[:topic]).to eq(:policy)
    end

    it "detects association topic" do
      expect(analyzer.analyze("Fix User association with posts")[:topic]).to eq(:association)
      expect(analyzer.analyze("Add belongs_to account to User")[:topic]).to eq(:association)
      expect(analyzer.analyze("Change User has_many relationship")[:topic]).to eq(:association)
    end

    it "defaults to :general for generic and non-topic requests" do
      expect(analyzer.analyze("Explain User")[:topic]).to eq(:general)
      expect(analyzer.analyze("Change User's status representation")[:topic]).to eq(:general)
      expect(analyzer.analyze("Some generic request")[:topic]).to eq(:general)
    end

    describe "adversarial scenario matrix" do
      it "evaluates validation scenarios accurately" do
        expect(analyzer.analyze("Add a validation to User")).to eq(action: :edit, entity: "User", topic: :validation)
        expect(analyzer.analyze("Why is User validation failing?")).to eq(action: :debug, entity: "User", topic: :validation)
        expect(analyzer.analyze("Change User email validation")).to eq(action: :edit, entity: "User", topic: :validation)
      end

      it "evaluates serialization scenarios accurately" do
        expect(analyzer.analyze("Change how User is serialized")).to eq(action: :edit, entity: "User", topic: :serialization)
        expect(analyzer.analyze("Add email to User JSON response")).to eq(action: :edit, entity: "User", topic: :serialization)
        expect(analyzer.analyze("Why is UserSerializer not showing email?")).to eq(action: :explain, entity: "User", topic: :serialization)
        expect(analyzer.analyze("Change the JSON representation of User")).to eq(action: :edit, entity: "User", topic: :serialization)
      end

      it "evaluates association scenarios accurately" do
        expect(analyzer.analyze("Add an association between User and Account")).to eq(action: :edit, entity: "User", topic: :association, association: nil)
        expect(analyzer.analyze("Why are User accounts not loading?")).to eq(action: :explain, entity: "User", topic: :general)
        expect(analyzer.analyze("Change User's posts association")).to eq(action: :edit, entity: "User", topic: :association, association: "posts")
      end

      it "evaluates policy scenarios accurately" do
        expect(analyzer.analyze("Change authorization for User")).to eq(action: :edit, entity: "User", topic: :policy)
        expect(analyzer.analyze("Why can this user not access User?")).to eq(action: :explain, entity: "User", topic: :general)
        expect(analyzer.analyze("Update UserPolicy")).to eq(action: :edit, entity: "User", topic: :policy)
        expect(analyzer.analyze("Update authorization policy for User")).to eq(action: :edit, entity: "User", topic: :policy)
      end

      it "evaluates job classification accurately" do
        expect(analyzer.analyze("Change UserJob")).to eq(action: :edit, entity: "User", topic: :job)
        expect(analyzer.analyze("Change UserWorker")).to eq(action: :edit, entity: "User", topic: :job)
        expect(analyzer.analyze("Why is UserJob failing?")).to eq(action: :debug, entity: "User", topic: :job)
        expect(analyzer.analyze("Why is UserWorker failing?")).to eq(action: :debug, entity: "User", topic: :job)
        expect(analyzer.analyze("Why is the User job failing?")).to eq(action: :debug, entity: "User", topic: :job)
        expect(analyzer.analyze("Why is the User worker failing?")).to eq(action: :debug, entity: "User", topic: :job)
        expect(analyzer.analyze("User job is failing")).to eq(action: :debug, entity: "User", topic: :job)
        expect(analyzer.analyze("User worker is failing")).to eq(action: :debug, entity: "User", topic: :job)
        expect(analyzer.analyze("Update background job for User")).to eq(action: :edit, entity: "User", topic: :job)
        expect(analyzer.analyze("Add a background worker for User")).to eq(action: :edit, entity: "User", topic: :job)
        expect(analyzer.analyze("Sidekiq User job")).to eq(action: :edit, entity: "User", topic: :job)
        expect(analyzer.analyze("Sidekiq UserJob")).to eq(action: :edit, entity: "User", topic: :job)
        expect(analyzer.analyze("enqueue UserJob")).to eq(action: :edit, entity: "User", topic: :job)
        expect(analyzer.analyze("perform_later UserJob")).to eq(action: :edit, entity: "User", topic: :job)
        expect(analyzer.analyze("perform_async UserJob")).to eq(action: :edit, entity: "User", topic: :job)
      end

      it "avoids false positives for ordinary-language job, worker, perform, and enqueue phrases" do
        expect(analyzer.analyze("Perform User migration")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Perform User validation")).to eq(action: :edit, entity: "User", topic: :validation)
        expect(analyzer.analyze("Perform the requested update")).to eq(action: :edit, entity: nil, topic: :general)
        expect(analyzer.analyze("Perform task for User")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Perform an action for User")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Perform User cleanup")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Enqueue User notification")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Update User job title")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Update User's job title")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Change User job preferences")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Update User's job history")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Discuss User job application")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Improve worker productivity")).to eq(action: :edit, entity: nil, topic: :general)
        expect(analyzer.analyze("Change worker responsibilities")).to eq(action: :edit, entity: nil, topic: :general)
        expect(analyzer.analyze("Change worker responsibilities for User")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Update worker documentation")).to eq(action: :edit, entity: nil, topic: :general)
        expect(analyzer.analyze("Update User's employment information")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Change user workflow")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Update user background processing")).to eq(action: :edit, entity: "User", topic: :general)
      end

      it "evaluates mailer classification and avoids false positives" do
        expect(analyzer.analyze("Change UserMailer")).to eq(action: :edit, entity: "User", topic: :mailer)
        expect(analyzer.analyze("Update UserMailer")).to eq(action: :edit, entity: "User", topic: :mailer)
        expect(analyzer.analyze("Why is UserMailer failing?")).to eq(action: :debug, entity: "User", topic: :mailer)
        expect(analyzer.analyze("Why is UserMailer not delivering?")).to eq(action: :explain, entity: "User", topic: :mailer)
        expect(analyzer.analyze("Update the User welcome email template")).to eq(action: :edit, entity: "User", topic: :mailer)
        expect(analyzer.analyze("Change the password reset email template for User")).to eq(action: :edit, entity: "User", topic: :mailer)
        expect(analyzer.analyze("Change Admin::UserMailer", models: ["Admin::User"])).to eq(action: :edit, entity: "Admin::User", topic: :mailer)
        expect(analyzer.analyze("Why is Admin::UserMailer failing?", models: ["Admin::User"])).to eq(action: :debug, entity: "Admin::User", topic: :mailer)

        expect(analyzer.analyze("Update User's email address")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Change User email preferences")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Update User's email validation")).to eq(action: :edit, entity: "User", topic: :validation)
        expect(analyzer.analyze("Verify User email format")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Change User mailing address")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Update notification email settings")).to eq(action: :edit, entity: nil, topic: :general)
        expect(analyzer.analyze("Why is User email field blank?")).to eq(action: :explain, entity: "User", topic: :general)
        expect(analyzer.analyze("Add email uniqueness validation to User")).to eq(action: :edit, entity: "User", topic: :validation)
        expect(analyzer.analyze("Discuss User email confirmation workflow")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Update User's email column")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Send User an email")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Send a welcome email to User")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Email User after registration")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Notify User by email")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Change User notification email")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Why isn't the User email being sent?")).to eq(action: :debug, entity: "User", topic: :mailer)
        expect(analyzer.analyze("Change notification preferences for User")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Change email preferences for User")).to eq(action: :edit, entity: "User", topic: :general)
      end

      it "evaluates concern classification accurately" do
        expect(analyzer.analyze("Change the Auditable concern")).to eq(action: :edit, entity: nil, topic: :concern)
        expect(analyzer.analyze("Fix the Auditable concern for User")).to eq(action: :edit, entity: "User", topic: :concern)
        expect(analyzer.analyze("Update the User concern")).to eq(action: :edit, entity: "User", topic: :concern)
        expect(analyzer.analyze("Change the User model concern")).to eq(action: :edit, entity: "User", topic: :concern)
        expect(analyzer.analyze("Why is the Auditable concern failing?")).to eq(action: :debug, entity: nil, topic: :concern)
        expect(analyzer.analyze("Implement ActiveSupport::Concern for User")).to eq(action: :edit, entity: "User", topic: :concern)
        expect(analyzer.analyze("Fix the User model mixin")).to eq(action: :edit, entity: "User", topic: :concern)
      end

      it "evaluates controller concern classification accurately" do
        expect(analyzer.analyze("Change User controller concern")).to eq(action: :edit, entity: "User", topic: :concern)
        expect(analyzer.analyze("Change the User controller concern")).to eq(action: :edit, entity: "User", topic: :concern)
        expect(analyzer.analyze("Change the Authenticatable controller concern for User")).to eq(action: :edit, entity: "User", topic: :concern)
        expect(analyzer.analyze("Change the Authenticatable controller concern")).to eq(action: :edit, entity: nil, topic: :concern)
      end

      it "avoids false positives for ordinary-language include, extend, mixin, and concern words" do
        expect(analyzer.analyze("Include User in the response")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Include validation for User")).to eq(action: :edit, entity: "User", topic: :validation)
        expect(analyzer.analyze("Extend the User API")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Mix in authentication")).to eq(action: :edit, entity: nil, topic: :general)
        expect(analyzer.analyze("Include caching")).to eq(action: :edit, entity: nil, topic: :general)
        expect(analyzer.analyze("What does User include?")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("What does User extend?")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Add a validation to User")).to eq(action: :edit, entity: "User", topic: :validation)
        expect(analyzer.analyze("Address security concern in User")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Discuss privacy concern for User")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("This is a major performance concern for User")).to eq(action: :edit, entity: "User", topic: :general)
        expect(analyzer.analyze("Address User latency concerns")).to eq(action: :edit, entity: "User", topic: :general)
      end

      it "evaluates service classification and avoids false positives" do
        expect(analyzer.analyze("Change UserService")).to eq(action: :edit, entity: "User", topic: :service)
        expect(analyzer.analyze("Why is the User service failing?")).to eq(action: :debug, entity: "User", topic: :service)
        expect(analyzer.analyze("Move this User operation into a service")).to eq(action: :edit, entity: "User", topic: :service)
        expect(analyzer.analyze("Update User creator")).to eq(action: :edit, entity: "User", topic: :general)
      end

      it "evaluates general / explain / debug scenarios accurately" do
        expect(analyzer.analyze("Explain User")).to eq(action: :explain, entity: "User", topic: :general)
        expect(analyzer.analyze("Debug User")).to eq(action: :debug, entity: "User", topic: :general)
        expect(analyzer.analyze("Why is User failing?")).to eq(action: :debug, entity: "User", topic: :general)
        expect(analyzer.analyze("How does User work?")).to eq(action: :explain, entity: "User", topic: :general)
      end
    end

    describe "adversarial compound / ambiguous requests" do
      it "safely falls back to :general when multiple distinct topics compete" do
        expect(analyzer.analyze("Change User serialization and fix the validation")[:topic]).to eq(:general)
        expect(analyzer.analyze("Why is UserSerializer failing validation?")[:topic]).to eq(:general)
        expect(analyzer.analyze("Change the User email validation in the JSON response")[:topic]).to eq(:general)
        expect(analyzer.analyze("Debug User because posts are missing from the response")[:topic]).to eq(:general)
        expect(analyzer.analyze("Update UserPolicy and its JSON representation")[:topic]).to eq(:general)
      end

      it "isolates single dominant topic when non-colliding prose is present" do
        expect(analyzer.analyze("Fix the User service that sends email")[:topic]).to eq(:service)
        expect(analyzer.analyze("Change notification preferences for User")[:topic]).to eq(:general)
      end
    end

    describe "compound entity resolution" do
      it "resolves UserSerializer to User" do
        expect(analyzer.analyze("Change UserSerializer")).to eq(
          action: :edit,
          entity: "User",
          topic: :serialization
        )
      end

      it "resolves UserPolicy to User" do
        expect(analyzer.analyze("Update UserPolicy")).to eq(
          action: :edit,
          entity: "User",
          topic: :policy
        )
      end

      it "resolves UserJob to User" do
        expect(analyzer.analyze("Change UserJob")).to eq(
          action: :edit,
          entity: "User",
          topic: :job
        )
      end

      it "resolves UserWorker to User" do
        expect(analyzer.analyze("Change UserWorker")).to eq(
          action: :edit,
          entity: "User",
          topic: :job
        )
        expect(analyzer.analyze("Why is UserWorker failing?")).to eq(
          action: :debug,
          entity: "User",
          topic: :job
        )
      end

      it "resolves UserMailer to User" do
        expect(analyzer.analyze("Change UserMailer")).to eq(
          action: :edit,
          entity: "User",
          topic: :mailer
        )
      end

      it "resolves UserService to User" do
        expect(analyzer.analyze("Change UserService")).to eq(
          action: :edit,
          entity: "User",
          topic: :service
        )
      end

      it "resolves namespaced compound artifact constants" do
        scoped_analyzer = described_class.new(models: ["Admin::User", "Billing::Invoice"])
        expect(scoped_analyzer.analyze("Change Admin::UserSerializer")).to eq(
          action: :edit,
          entity: "Admin::User",
          topic: :serialization
        )
        expect(scoped_analyzer.analyze("Update Billing::InvoicePolicy")).to eq(
          action: :edit,
          entity: "Billing::Invoice",
          topic: :policy
        )
        expect(scoped_analyzer.analyze("Change Admin::UserJob")).to eq(
          action: :edit,
          entity: "Admin::User",
          topic: :job
        )
        expect(scoped_analyzer.analyze("Change Admin::UserWorker")).to eq(
          action: :edit,
          entity: "Admin::User",
          topic: :job
        )
        expect(scoped_analyzer.analyze("Change Admin::UserMailer")).to eq(
          action: :edit,
          entity: "Admin::User",
          topic: :mailer
        )
      end

      it "preserves standard entity resolution for base models" do
        expect(analyzer.analyze("Change User")[:entity]).to eq("User")
        expect(analyzer.analyze("Add validation to User")[:entity]).to eq("User")
        expect(analyzer.analyze("Explain Shop")[:entity]).to eq("Shop")
        expect(analyzer.analyze("Change Billing::Invoice")[:entity]).to eq("Billing::Invoice")
      end

      it "fails closed when compound artifact references an unknown base entity" do
        expect(analyzer.analyze("Change SomeRandomSerializer")).to eq(
          action: :edit,
          entity: nil,
          topic: :serialization
        )
        expect(analyzer.analyze("Update SomeRandomPolicy")).to eq(
          action: :edit,
          entity: nil,
          topic: :policy
        )
        expect(analyzer.analyze("Change SomeRandomWorker")).to eq(
          action: :edit,
          entity: nil,
          topic: :job
        )
        expect(analyzer.analyze("Change SomeRandomMailer")).to eq(
          action: :edit,
          entity: nil,
          topic: :mailer
        )
      end

      it "does not treat arbitrary words as artifact constants" do
        expect(analyzer.analyze("Update User creator")).to eq(
          action: :edit,
          entity: "User",
          topic: :general
        )
        expect(analyzer.analyze("Change notification preferences for User")).to eq(
          action: :edit,
          entity: "User",
          topic: :general
        )
        expect(analyzer.analyze("Change email validation for User")).to eq(
          action: :edit,
          entity: "User",
          topic: :validation
        )
      end

      it "handles multiple compound artifacts without guessing" do
        expect(analyzer.analyze("Change UserSerializer and UserPolicy")).to eq(
          action: :edit,
          entity: "User",
          topic: :general,
          topics: [:serialization, :policy]
        )
        expect(analyzer.analyze("Change UserWorker and UserSerializer")).to eq(
          action: :edit,
          entity: "User",
          topic: :general,
          topics: [:serialization, :job]
        )
      end
    end

    it "preserves full result with action, entity, and topic" do
      result = analyzer.analyze("Change how User's posts are serialized")
      expect(result[:action]).to eq(:edit)
      expect(result[:entity]).to eq("User")
      expect(result[:topic]).to eq(:serialization)
    end

    it "handles unknown entities while still detecting topic" do
      result = analyzer.analyze("Add validation to Account")
      expect(result[:action]).to eq(:edit)
      expect(result[:entity]).to be_nil
      expect(result[:topic]).to eq(:validation)
    end
  end

  describe "association intent extraction (M8.1a)" do
    let(:analyzer) { described_class.new(models: ["User", "Account"]) }

    it "extracts specific association name when provided (posts)" do
      result = analyzer.analyze("Change User's posts association.")
      expect(result).to eq(
        action: :edit,
        entity: "User",
        topic: :association,
        association: "posts"
      )
    end

    it "extracts another association name correctly (account)" do
      result = analyzer.analyze("Change User's account association.")
      expect(result).to eq(
        action: :edit,
        entity: "User",
        topic: :association,
        association: "account"
      )
    end

    it "returns association: nil when no specific association is identified" do
      result = analyzer.analyze("Change User associations.")
      expect(result).to eq(
        action: :edit,
        entity: "User",
        topic: :association,
        association: nil
      )
    end

    it "extracts association across varied natural language patterns" do
      expect(analyzer.analyze("Change User's posts relationship.")[:association]).to eq("posts")
      expect(analyzer.analyze("Change the posts association on User.")[:association]).to eq("posts")
      expect(analyzer.analyze("Change User posts association.")[:association]).to eq("posts")
      expect(analyzer.analyze("Change User association posts.")[:association]).to eq("posts")
      expect(analyzer.analyze("Fix User association with posts")[:association]).to eq("posts")
      expect(analyzer.analyze("Add belongs_to account to User")[:association]).to eq("account")
      expect(analyzer.analyze("Change User has_many :posts association")[:association]).to eq("posts")
    end

    it "evaluates association: nil for non-association requests while preserving contract" do
      validation_result = analyzer.analyze("Add email validation to User")
      expect(validation_result[:association]).to be_nil
      expect(validation_result).to eq(
        action: :edit,
        entity: "User",
        topic: :validation
      )
    end
  end

  describe "natural-language topic intent preservation for jobs and mailers (M8.3)" do
    let(:analyzer) { described_class.new(models: ["User", "Admin::User"]) }

    describe "positive job intent" do
      it "classifies edit request with 'User job behavior' as :job" do
        expect(analyzer.analyze("Change User job behavior.")).to eq(
          action: :edit,
          entity: "User",
          topic: :job
        )
      end

      it "classifies natural-language job relationship 'the job that processes User' as :job" do
        expect(analyzer.analyze("Change the job that processes User.")).to eq(
          action: :edit,
          entity: "User",
          topic: :job
        )
      end

      it "classifies worker terminology 'User worker behavior' as :job" do
        expect(analyzer.analyze("Change User worker behavior.")).to eq(
          action: :edit,
          entity: "User",
          topic: :job
        )
      end

      it "classifies debug request 'Why did the User job fail?' as debug action and :job topic" do
        expect(analyzer.analyze("Why did the User job fail?")).to eq(
          action: :debug,
          entity: "User",
          topic: :job
        )
      end

      it "preserves existing PascalCase job and worker classification" do
        expect(analyzer.analyze("Change UserJob")).to eq(action: :edit, entity: "User", topic: :job)
        expect(analyzer.analyze("Change UserWorker")).to eq(action: :edit, entity: "User", topic: :job)
        expect(analyzer.analyze("Change Admin::UserJob")).to eq(action: :edit, entity: "Admin::User", topic: :job)
        expect(analyzer.analyze("Change Admin::UserWorker")).to eq(action: :edit, entity: "Admin::User", topic: :job)
      end
    end

    describe "job false-positive protection" do
      it "does not classify conversational use of 'good job' as a job task" do
        result = analyzer.analyze("Change the User description to say good job.")
        expect(result[:topic]).to eq(:general)
      end

      it "does not classify conversational use of 'hard worker' as a job task" do
        result = analyzer.analyze("Change User profile to say hard worker.")
        expect(result[:topic]).to eq(:general)
      end
    end

    describe "positive mailer intent" do
      it "classifies explicit mailer request 'Change User mailer.' as :mailer" do
        expect(analyzer.analyze("Change User mailer.")).to eq(
          action: :edit,
          entity: "User",
          topic: :mailer
        )
      end

      it "classifies email delivery request 'Change the email sent when User is created.' as :mailer" do
        expect(analyzer.analyze("Change the email sent when User is created.")).to eq(
          action: :edit,
          entity: "User",
          topic: :mailer
        )
      end

      it "classifies email notification request 'Change User email notification.' as :mailer" do
        expect(analyzer.analyze("Change User email notification.")).to eq(
          action: :edit,
          entity: "User",
          topic: :mailer
        )
      end

      it "classifies debug email delivery 'Why isn't the User email being sent?' as debug action and :mailer topic" do
        expect(analyzer.analyze("Why isn't the User email being sent?")).to eq(
          action: :debug,
          entity: "User",
          topic: :mailer
        )
      end
    end

    describe "mailer false-positive protection" do
      it "does not classify 'Change User email validation.' as a mailer task" do
        result = analyzer.analyze("Change User email validation.")
        expect(result[:topic]).to eq(:validation)
      end

      it "does not classify 'Add email to User.' as a mailer task" do
        result = analyzer.analyze("Add email to User.")
        expect(result[:topic]).to eq(:general)
      end
    end

    describe "topic precedence and multi-topic safety" do
      it "safely falls back to :general when validation and job signals compete" do
        result = analyzer.analyze("Change User validation and job behavior.")
        expect(result[:topic]).to eq(:general)
      end

      it "safely falls back to :general when mailer and serialization signals compete" do
        result = analyzer.analyze("Change User mailer and serializer.")
        expect(result[:topic]).to eq(:general)
      end
    end

    describe "debug action boundary" do
      it "does not treat words containing 'fail' such as 'failover' in an edit request as a debug action" do
        result = analyzer.analyze("Change User failover configuration.")
        expect(result[:action]).to eq(:edit)
      end
    end
  end

  describe "compound service artifact resolution (M9.1)" do
    let(:analyzer) { described_class.new(models: ["User", "Admin::User"]) }

    describe "positive service artifact resolution" do
      it "resolves simple UserService to model User" do
        expect(analyzer.analyze("Change UserService.")).to eq(
          action: :edit,
          entity: "User",
          topic: :service
        )
      end

      it "resolves compound UserRegistrationService to model User" do
        expect(analyzer.analyze("Change UserRegistrationService.")).to eq(
          action: :edit,
          entity: "User",
          topic: :service
        )
      end

      it "resolves namespaced Admin::UserService to model Admin::User" do
        expect(analyzer.analyze("Change Admin::UserService.")).to eq(
          action: :edit,
          entity: "Admin::User",
          topic: :service
        )
      end

      it "resolves compound namespaced Admin::UserRegistrationService to model Admin::User" do
        expect(analyzer.analyze("Change Admin::UserRegistrationService.")).to eq(
          action: :edit,
          entity: "Admin::User",
          topic: :service
        )
      end
    end

    describe "existing artifact regression safety" do
      it "preserves resolution for non-service compound artifacts" do
        expect(analyzer.analyze("Change UserSerializer.")).to eq(
          action: :edit,
          entity: "User",
          topic: :serialization
        )
        expect(analyzer.analyze("Change UserPolicy.")).to eq(
          action: :edit,
          entity: "User",
          topic: :policy
        )
        expect(analyzer.analyze("Change UserJob.")).to eq(
          action: :edit,
          entity: "User",
          topic: :job
        )
        expect(analyzer.analyze("Change UserWorker.")).to eq(
          action: :edit,
          entity: "User",
          topic: :job
        )
        expect(analyzer.analyze("Change UserMailer.")).to eq(
          action: :edit,
          entity: "User",
          topic: :mailer
        )
      end

      it "preserves resolution for namespaced non-service compound artifacts" do
        expect(analyzer.analyze("Change Admin::UserSerializer.")).to eq(
          action: :edit,
          entity: "Admin::User",
          topic: :serialization
        )
        expect(analyzer.analyze("Change Admin::UserPolicy.")).to eq(
          action: :edit,
          entity: "Admin::User",
          topic: :policy
        )
        expect(analyzer.analyze("Change Admin::UserJob.")).to eq(
          action: :edit,
          entity: "Admin::User",
          topic: :job
        )
        expect(analyzer.analyze("Change Admin::UserWorker.")).to eq(
          action: :edit,
          entity: "Admin::User",
          topic: :job
        )
        expect(analyzer.analyze("Change Admin::UserMailer.")).to eq(
          action: :edit,
          entity: "Admin::User",
          topic: :mailer
        )
      end
    end

    describe "model-name protection" do
      it "preserves ordinary model entity resolution when UserRegistration is an actual model" do
        model_analyzer = described_class.new(models: ["User", "UserRegistration"])
        expect(model_analyzer.analyze("Change UserRegistration.")).to eq(
          action: :edit,
          entity: "UserRegistration",
          topic: :general
        )
      end
    end

    describe "overlapping model names (longer model wins)" do
      it "resolves to longer model when base names overlap (Case 1: User vs UserProfile)" do
        overlapping_analyzer = described_class.new(models: ["User", "UserProfile"])
        expect(overlapping_analyzer.analyze("Change UserProfileRegistrationService.")).to eq(
          action: :edit,
          entity: "UserProfile",
          topic: :service
        )
      end

      it "resolves to longer namespaced model when names overlap (Case 2: Admin::User vs Admin::UserProfile)" do
        overlapping_analyzer = described_class.new(models: ["Admin::User", "Admin::UserProfile"])
        expect(overlapping_analyzer.analyze("Change Admin::UserProfileRegistrationService.")).to eq(
          action: :edit,
          entity: "Admin::UserProfile",
          topic: :service
        )
      end
    end

    describe "fail-closed and boundary behavior" do
      it "fails closed and returns entity: nil when service artifact cannot be mapped to any project model" do
        expect(analyzer.analyze("Change PaymentProcessingService.")).to eq(
          action: :edit,
          entity: nil,
          topic: :service
        )
      end

      it "does not match model prefix without valid word boundary (Case 3: Post in PostcardService)" do
        post_analyzer = described_class.new(models: ["Post"])
        expect(post_analyzer.analyze("Change PostcardService.")).to eq(
          action: :edit,
          entity: nil,
          topic: :service
        )
      end
    end
  end

  describe "natural-language service intent extraction (M9.2)" do
    let(:analyzer) { described_class.new(models: ["User", "Admin::User"]) }

    it "extracts service action for natural-language registration request" do
      result = analyzer.analyze("Change the service used for User registration.")
      expect(result[:action]).to eq(:edit)
      expect(result[:entity]).to eq("User")
      expect(result[:topic]).to eq(:service)
      expect(result[:service_action]).to eq("registration")
    end

    it "extracts service action for natural-language import request" do
      result = analyzer.analyze("Change the service that imports Users.")
      expect(result[:action]).to eq(:edit)
      expect(result[:entity]).to eq("User")
      expect(result[:topic]).to eq(:service)
      expect(result[:service_action]).to eq("import")
    end

    it "returns nil service_action for ambiguous natural-language service request" do
      result = analyzer.analyze("Change the service for User.")
      expect(result[:action]).to eq(:edit)
      expect(result[:entity]).to eq("User")
      expect(result[:topic]).to eq(:service)
      expect(result[:service_action]).to be_nil
    end

    it "prefers nil service_action over false-positive verb when request uses generic filler verbs" do
      result = analyzer.analyze("Change the service that handles User registration requests.")
      expect(result[:action]).to eq(:edit)
      expect(result[:entity]).to eq("User")
      expect(result[:topic]).to eq(:service)
      expect(result[:service_action]).to be_nil
    end
  end

  describe "explicit concern-name intent extraction (M10.1)" do
    let(:analyzer) { described_class.new(models: ["User"]) }

    it "extracts concern name for Auditable concern on User" do
      result = analyzer.analyze("Change the Auditable concern for User.")
      expect(result).to eq(
        action: :edit,
        entity: "User",
        topic: :concern,
        concern_name: "Auditable"
      )
    end

    it "extracts concern name for Searchable concern on User" do
      result = analyzer.analyze("Change the Searchable concern for User.")
      expect(result).to eq(
        action: :edit,
        entity: "User",
        topic: :concern,
        concern_name: "Searchable"
      )
    end

    it "returns no specific concern name for generic concern request" do
      result = analyzer.analyze("Change the concern for User.")
      expect(result[:action]).to eq(:edit)
      expect(result[:entity]).to eq("User")
      expect(result[:concern_name]).to be_nil
    end

    it "returns no specific concern name for generic model concern request" do
      result = analyzer.analyze("Change the User model concern.")
      expect(result[:action]).to eq(:edit)
      expect(result[:entity]).to eq("User")
      expect(result[:topic]).to eq(:concern)
      expect(result[:concern_name]).to be_nil
    end

    it "leaves existing validation result unchanged" do
      result = analyzer.analyze("Change User validation.")
      expect(result).to eq(
        action: :edit,
        entity: "User",
        topic: :validation
      )
      expect(result[:concern_name]).to be_nil
    end

    it "does not treat unrelated uses of concern as named-concern requests" do
      expect(analyzer.analyze("Address security concern in User.")).to eq(
        action: :edit,
        entity: "User",
        topic: :general
      )
      expect(analyzer.analyze("Discuss privacy concern for User.")).to eq(
        action: :edit,
        entity: "User",
        topic: :general
      )
      expect(analyzer.analyze("This is a major performance concern for User.")).to eq(
        action: :edit,
        entity: "User",
        topic: :general
      )
      expect(analyzer.analyze("Address User latency concerns.")).to eq(
        action: :edit,
        entity: "User",
        topic: :general
      )
    end
  end

  describe "multi-topic intent extraction (M11.1)" do
    let(:analyzer) { described_class.new(models: ["User"]) }

    it "extracts distinct topics for validation and serialization" do
      result = analyzer.analyze("Add validation to User and update its serializer.")
      expect(result[:action]).to eq(:edit)
      expect(result[:entity]).to eq("User")
      expect(result[:topic]).to eq(:general)
      expect(result[:topics]).to contain_exactly(:validation, :serialization)
    end

    it "recognizes job and mailer as distinct topics without multi-entity misclassification" do
      result = analyzer.analyze("Fix UserJob and update UserMailer.")
      expect(result[:action]).to eq(:edit)
      expect(result[:entity]).to eq("User")
      expect(result[:topic]).to eq(:general)
      expect(result[:topics]).to contain_exactly(:job, :mailer)
    end

    it "recognizes policy and validation as distinct topics" do
      result = analyzer.analyze("Update User policy and add validation.")
      expect(result[:action]).to eq(:edit)
      expect(result[:entity]).to eq("User")
      expect(result[:topic]).to eq(:general)
      expect(result[:topics]).to contain_exactly(:policy, :validation)
    end

    it "recognizes association and serialization while preserving association metadata" do
      result = analyzer.analyze("Update User's posts association and serializer.")
      expect(result[:action]).to eq(:edit)
      expect(result[:entity]).to eq("User")
      expect(result[:topic]).to eq(:general)
      expect(result[:topics]).to contain_exactly(:association, :serialization)
      expect(result[:association]).to eq("posts")
    end

    it "preserves exact result contract for single-topic request without topics key" do
      result = analyzer.analyze("Add validation to User.")
      expect(result).to eq(
        action: :edit,
        entity: "User",
        topic: :validation
      )
      expect(result).not_to have_key(:topics)
    end

    it "does not duplicate topics or invent a second topic for repeated mentions" do
      result = analyzer.analyze("Add validation to User and verify its validation rules.")
      expect(result).to eq(
        action: :edit,
        entity: "User",
        topic: :validation
      )
      expect(result).not_to have_key(:topics)
    end

    describe "incidental words and false-positive protection" do
      it "does not classify ordinary worker productivity as background-job intent" do
        result = analyzer.analyze("Improve worker productivity and validate the result.")
        expect(result[:action]).to eq(:edit)
        expect(result[:entity]).to be_nil
        expect(result[:topic]).to eq(:validation)
        expect(result).not_to have_key(:topics)
      end

      it "does not classify job title as background-job intent" do
        result = analyzer.analyze("Update User's job title and serializer.")
        expect(result[:action]).to eq(:edit)
        expect(result[:entity]).to eq("User")
        expect(result[:topic]).to eq(:serialization)
        expect(result).not_to have_key(:topics)
      end

      it "does not alter action classification or cause edit-specific behavior on non-edit phrases" do
        result = analyzer.analyze("Discuss User validation and serialization concepts.")
        expect(result[:action]).to eq(:edit)
        expect(result[:entity]).to eq("User")
        expect(result[:topic]).to eq(:general)
        expect(result[:topics]).to contain_exactly(:validation, :serialization)

        explain_result = analyzer.analyze("Explain User validation and serialization.")
        expect(explain_result[:action]).to eq(:explain)
        expect(explain_result[:entity]).to eq("User")
        expect(explain_result[:topic]).to eq(:general)
        expect(explain_result[:topics]).to contain_exactly(:validation, :serialization)
      end
    end
  end
end