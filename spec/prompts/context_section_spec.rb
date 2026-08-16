# spec/prompts/context_section_spec.rb
require 'spec_helper'
require 'prompts/context_section'

RSpec.describe Prompts::ContextSection do
  describe '#build' do
    it 'correctly formats a single file with a ruby extension' do
      files = [
        {
          category: :model,
          path: 'app/models/user.rb',
          content: 'class User < ApplicationRecord; end'
        }
      ]

      expected_output = <<~TEXT
        ## MODEL

        File: app/models/user.rb

        ```ruby
        class User < ApplicationRecord; end
        ```
      TEXT

      expect(subject.build(files)).to eq(expected_output)
    end
  end
end
