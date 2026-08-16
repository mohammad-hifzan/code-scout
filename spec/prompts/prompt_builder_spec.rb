# spec/prompts/prompt_builder_spec.rb
require 'spec_helper'
require 'prompts/prompt_builder'
require 'prompts/header'
require 'prompts/instructions'
require 'prompts/context_section'
require 'prompts/task'

RSpec.describe PromptBuilder do
  describe '#build' do
    it 'assembles prompt sections in the correct order with correct separators' do
      # Mock dependencies
      header_double = instance_double(Prompts::Header, build: "HEADER")
      instructions_double = instance_double(Prompts::Instructions, build: "INSTRUCTIONS")
      context_section_double = instance_double(Prompts::ContextSection, build: "CONTEXT")
      task_double = instance_double(Prompts::Task, build: "TASK")

      # Stub .new to return mocks
      allow(Prompts::Header).to receive(:new).and_return(header_double)
      allow(Prompts::Instructions).to receive(:new).and_return(instructions_double)
      allow(Prompts::ContextSection).to receive(:new).and_return(context_section_double)
      allow(Prompts::Task).to receive(:new).and_return(task_double)

      # Inputs
      files = [
        {
          category: :model,
          path: "app/models/user.rb",
          content: "class User < ApplicationRecord; end"
        }
      ]
      request = "Do the thing"

      # Execute
      builder = PromptBuilder.new
      prompt = builder.build(request: request, files: files)

      # Verify calls to dependencies
      expect(Prompts::Header).to have_received(:new).exactly(1).time
      expect(header_double).to have_received(:build).exactly(1).time

      expect(Prompts::Instructions).to have_received(:new).exactly(1).time
      expect(instructions_double).to have_received(:build).exactly(1).time

      expect(Prompts::ContextSection).to have_received(:new).exactly(1).time
      expect(context_section_double).to have_received(:build).with(files).exactly(1).time

      expect(Prompts::Task).to have_received(:new).exactly(1).time
      expect(task_double).to have_received(:build).with(request).exactly(1).time

      # Verify the final assembled prompt
      expected_prompt = "HEADER\n\nINSTRUCTIONS\n\nCONTEXT\n\nTASK"
      expect(prompt).to eq(expected_prompt)
    end
  end
end
