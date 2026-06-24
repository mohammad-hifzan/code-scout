# lib/view_analyzer.rb

class ViewAnalyzer
  def analyze(view_path)
    return unless File.exist?(view_path)

    content = File.read(view_path)

    {
      view: view_path,

      partials:
        extract_partials(content),

      object_renders:
        extract_object_renders(content),

      collection_renders:
        extract_collection_renders(content),

      instance_variables:
        extract_instance_variables(content),

      form_models:
        extract_form_models(content),

      turbo_frames:
        extract_turbo_frames(content),

      stimulus_controllers:
        extract_stimulus_controllers(content)
    }
  end

  private

  def extract_partials(content)
    partials = []

    partials.concat(
      content.scan(
        /render\s+["']([^"']+)["']/
      ).flatten
    )

    partials.concat(
      content.scan(
        /render\s+partial:\s*["']([^"']+)["']/
      ).flatten
    )

    partials.uniq.sort
  end

  def extract_object_renders(content)
    content
      .scan(/render\s+(@\w+)/)
      .flatten
      .uniq
      .sort
  end

  def extract_collection_renders(content)
    content
      .scan(/collection:\s*(@\w+)/)
      .flatten
      .uniq
      .sort
  end

  def extract_instance_variables(content)
    content
      .scan(/@\w+/)
      .uniq
      .sort
  end

  def extract_form_models(content)
    content
      .scan(/model:\s*(@\w+)/)
      .flatten
      .uniq
      .sort
  end

  def extract_turbo_frames(content)
    content
      .scan(
        /turbo_frame_tag\s+["']([^"']+)["']/
      )
      .flatten
      .uniq
      .sort
  end

  def extract_stimulus_controllers(content)
    content
      .scan(
        /data-controller=["']([^"']+)["']/
      )
      .flatten
      .flat_map(&:split)
      .uniq
      .sort
  end
end