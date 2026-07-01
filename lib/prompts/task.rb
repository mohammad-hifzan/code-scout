# lib/prompts/task.rb

module Prompts
  class Task
    def build(task)
      <<~TEXT
        ## TASK

        #{task}
      TEXT
    end
  end
end