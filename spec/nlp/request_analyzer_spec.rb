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
        expect(analyzer.analyze("Add an association between User and Account")).to eq(action: :edit, entity: "User", topic: :association)
        expect(analyzer.analyze("Why are User accounts not loading?")).to eq(action: :explain, entity: "User", topic: :general)
        expect(analyzer.analyze("Change User's posts association")).to eq(action: :edit, entity: "User", topic: :association)
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
        expect(analyzer.analyze("Why isn't the User email being sent?")).to eq(action: :explain, entity: "User", topic: :general)
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
          topic: :general
        )
        expect(analyzer.analyze("Change UserWorker and UserSerializer")).to eq(
          action: :edit,
          entity: "User",
          topic: :general
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
end