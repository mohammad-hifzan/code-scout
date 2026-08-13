# frozen_string_literal: true

class ReferenceCategorizer
  def initialize
  end
  
  def categorize(files)
    result = {
      models: [],
      controllers: [],
      views: [],
      helpers: [],
      policies: [],
      services: [],
      jobs: [],
      mailers: [],
      concerns: [],
      others: []
    }

    return result if files.nil?

    files.each do |file|
      case file
      when %r{/app/models/concerns/},
           %r{/app/controllers/concerns/}
        result[:concerns] << file
      when %r{/app/models/}
        result[:models] << file
      when %r{/app/controllers/}
        result[:controllers] << file
      when %r{/app/views/}
        result[:views] << file
      when %r{/app/helpers/}
        result[:helpers] << file
      when %r{/app/policies/}
        result[:policies] << file
      when %r{/app/services/}
        result[:services] << file
      when %r{/app/jobs/}
        result[:jobs] << file
      when %r{/app/mailers/}
        result[:mailers] << file
      else
        result[:others] << file
      end
    end
    result
  end
end