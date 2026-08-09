# spec/analysis/view_analyzer_spec.rb
require 'spec_helper'
require 'analysis/view_analyzer'

RSpec.describe ViewAnalyzer do
  let(:analyzer) { ViewAnalyzer.new }

  describe '#analyze' do
    let(:view_path) { 'spec/fixtures/views/posts/index.html.erb' }

    context 'with a view that has various components' do
      before do
        allow(File).to receive(:exist?).with(view_path).and_return(true)
        allow(File).to receive(:read).with(view_path).and_return(view_content)
      end

      let(:view_content) do
        <<-ERB
          <h1>Posts</h1>

          <%= render "posts/post" %>
          <%= render partial: "shared/sidebar" %>
          <%= render 'another/partial' %>

          <%= render @post %>
          <%= render @posts %>
          <%= render collection: @archived_posts, as: :post %>

          <p>Current user: <%= @current_user.name %></p>
          <p>Local var: <%= local_var %></p>

          <%= form_with model: @post do |form| %>
            <%= form.text_field :title %>
            <%= form.submit %>
          <% end %>

          <%= form_for @comment do |f| %>
            <%= f.text_area :body %>
            <%= f.submit %>
          <% end %>

          <%= turbo_frame_tag "post_1" do %>
            <p>This is a turbo frame.</p>
          <% end %>

          <div data-controller="hello world"></div>
        ERB
      end

      it 'extracts all view components correctly' do
        result = analyzer.analyze(view_path)

        expect(result[:view]).to eq(view_path)
        expect(result[:partials]).to contain_exactly("posts/post", "shared/sidebar", "another/partial")
        expect(result[:object_renders]).to contain_exactly("@post", "@posts")
        expect(result[:collection_renders]).to contain_exactly("@archived_posts")
        expect(result[:instance_variables]).to contain_exactly("@post", "@posts", "@archived_posts", "@current_user", "@comment")
        expect(result[:form_models]).to contain_exactly("@post", "@comment")
        expect(result[:turbo_frames]).to contain_exactly("post_1")
        expect(result[:stimulus_controllers]).to contain_exactly("hello", "world")
      end
    end

    context 'with an empty view' do
      before do
        allow(File).to receive(:exist?).with(view_path).and_return(true)
        allow(File).to receive(:read).with(view_path).and_return('')
      end

      it 'returns empty arrays for all components' do
        result = analyzer.analyze(view_path)

        expect(result[:view]).to eq(view_path)
        expect(result[:partials]).to be_empty
        expect(result[:object_renders]).to be_empty
        expect(result[:collection_renders]).to be_empty
        expect(result[:instance_variables]).to be_empty
        expect(result[:form_models]).to be_empty
        expect(result[:turbo_frames]).to be_empty
        expect(result[:stimulus_controllers]).to be_empty
      end
    end

    context 'when view file does not exist' do
      before do
        allow(File).to receive(:exist?).with(view_path).and_return(false)
      end

      it 'returns nil' do
        expect(analyzer.analyze(view_path)).to be_nil
      end
    end
  end
end
