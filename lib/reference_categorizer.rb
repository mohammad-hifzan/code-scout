# frozen_string_literal: true

class ReferenceCategorizer
  def initialize
  end
  
  def categorize(files)
    {
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
    }.tap do |result|
      files.each do |file|
        case file
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

        when %r{/app/models/concerns/},
             %r{/app/controllers/concerns/}
          result[:concerns] << file

        else
          result[:others] << file
        end
      end
    end
  end
end