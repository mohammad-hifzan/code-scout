class ControllerAnalyzer
  def analyze(path)
    source = File.read(path)

    {
      controller: controller_name(path),
      modules: extract_modules(source),
      callbacks: extract_callbacks(source),
      actions: extract_actions(source)
    }
  end

  private

  def controller_name(path)
    File.basename(path, ".rb")
  end

  def extract_modules(source)
    source.scan(
      /^\s*include\s+([A-Z][A-Za-z0-9_:]+)/
    ).flatten
  end

  def extract_callbacks(source)
    {
      before: extract_callback(source, "before_action"),
      after: extract_callback(source, "after_action"),
      around: extract_callback(source, "around_action")
    }
  end

  def extract_callback(source, callback_type)
    source.scan(
      /#{Regexp.escape(callback_type)}\s+:([a-zA-Z_!?]+)/
    ).flatten
  end

  def extract_actions(source)
    action_names(source).map do |action|
      {
        name: action,
        authorizes: action_authorizes?(source, action),
        models: models_used_in_action(source, action)
      }
    end
  end

  def action_names(source)
    source
      .scan(/^\s*def\s+([a-zA-Z_!?]+)/)
      .flatten
      .reject { |name| private_method?(name) }
  end

  def private_method?(name)
    %w[
      initialize
      set_shop
      shop_params
      user_shop_role_params
    ].include?(name)
  end

  def action_authorizes?(source, action_name)
    body = action_body(source, action_name)

    body.include?("authorize")
  end

  def action_body(source, action_name)
    match = source.match(
      /def\s+#{Regexp.escape(action_name)}(.*?)^\s*end/m
    )

    match ? match[1] : ""
  end

  def models_used_in_action(source, action_name)
    body = action_body(source, action_name)

    models = []

    models += body.scan(
        /\b([A-Z][A-Za-z0-9_:]+)\.(?:new|find|find_by|create|create!|find_or_create_by)/
    ).flatten

    models += infer_instance_variable_models(body)

    models.uniq
  end

  def infer_instance_variable_models(body)
    mappings = {
      "@shop" => "Shop",
      "@user_shop_role" => "UserShopRole",
      "@user" => "User",
      "@outlet" => "Outlet"
    }

    mappings.filter_map do |ivar, model|
      model if body.include?(ivar)
    end
  end
end