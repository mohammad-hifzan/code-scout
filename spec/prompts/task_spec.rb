# spec/prompts/task_spec.rb
require 'spec_helper'
require 'prompts/task'

RSpec.describe Prompts::Task do
  describe '#build' do
    it 'formats the input string within a ## TASK markdown section' do
      task_content = "Refactor the User controller."
      expected_string = <<~TEXT
        ## TASK

        Refactor the User controller.
      TEXT

      task = Prompts::Task.new
      expect(task.build(task_content)).to eq(expected_string)
    end
  end
end
