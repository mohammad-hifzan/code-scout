require "spec_helper"
require "tempfile"
require_relative "../../lib/context/file_loader"

RSpec.describe FileLoader do
  subject(:loader) { described_class.new }

  def create_tempfile(content, name = "testfile")
    file = Tempfile.new(name)
    file.write(content)
    file.close
    file
  end

  describe "#load_files" do
    it "loads file contents" do
      file = create_tempfile("class Shop\nend", "shop.rb")
      result = loader.load_files([{ path: file.path, category: :primary }])
      expect(result.first[:content]).to include("class Shop")
      file.unlink
    end

    it "handles multiple files" do
      file1 = create_tempfile("content1")
      file2 = create_tempfile("content2")
      items = [{ path: file1.path }, { path: file2.path }]

      result = loader.load_files(items)

      expect(result.find { |r| r[:path] == file1.path }[:content]).to eq("content1")
      expect(result.find { |r| r[:path] == file2.path }[:content]).to eq("content2")
      file1.unlink
      file2.unlink
    end

    it "preserves all original item fields" do
      file = create_tempfile("content")
      item = { path: file.path, category: :model, relevance: 10 }
      result = loader.load_files([item])
      expect(result.first).to eq(item.merge(content: "content"))
      file.unlink
    end

    it "assigns content: nil for a nonexistent file" do
      items = [{ path: "/path/to/a/nonexistent/file.rb" }]
      result = loader.load_files(items)
      expect(result.first[:content]).to be_nil
    end

    it "loads an empty string for an empty file" do
      file = create_tempfile("")
      result = loader.load_files([{ path: file.path }])
      expect(result.first[:content]).to eq("")
      file.unlink
    end

    it "returns an empty array for empty input" do
      expect(loader.load_files([])).to eq([])
    end

    it "handles duplicate paths correctly" do
      file = create_tempfile("duplicate")
      items = [{ path: file.path, id: 1 }, { path: file.path, id: 2 }]
      result = loader.load_files(items)

      expect(result.count).to eq(2)
      expect(result[0][:content]).to eq("duplicate")
      expect(result[1][:content]).to eq("duplicate")
      file.unlink
    end

    it "raises a TypeError for a missing :path key" do
      expect { loader.load_files([{ category: :model }]) }.to raise_error(TypeError)
    end

    it "raises a TypeError for a nil :path" do
      expect { loader.load_files([{ path: nil }]) }.to raise_error(TypeError)
    end

    it "raises Errno::EACCES for an unreadable file" do
      file = create_tempfile("unreadable")
      File.chmod(0o000, file.path) # Remove all permissions

      expect { loader.load_files([{ path: file.path }]) }.to raise_error(Errno::EACCES)

      File.chmod(0o644, file.path) # Restore permissions for cleanup
      file.unlink
    end

    it "handles Unicode content correctly" do
      file = create_tempfile("你好世界") # "Hello World" in Chinese
      result = loader.load_files([{ path: file.path }])
      expect(result.first[:content]).to eq("你好世界")
      file.unlink
    end
  end

  describe "#load" do
    it "loads a hash of paths to contents for existing files" do
      file = create_tempfile("content")
      result = loader.load([file.path])
      expect(result).to eq({ file.path => "content" })
      file.unlink
    end

    it "skips nonexistent files from the output" do
      nonexistent_path = "/path/to/nonexistent_file"
      result = loader.load([nonexistent_path])
      expect(result).to be_empty
    end

    it "handles a mix of existing and nonexistent paths" do
      file = create_tempfile("mix")
      nonexistent_path = "/path/to/nonexistent_file"
      result = loader.load([file.path, nonexistent_path])
      expect(result).to eq({ file.path => "mix" })
      file.unlink
    end

    it "returns an empty hash for empty input" do
      expect(loader.load([])).to eq({})
    end

    it "raises Errno::EACCES for an unreadable file" do
      file = create_tempfile("unreadable")
      File.chmod(0o000, file.path) # Remove all permissions

      expect { loader.load([file.path]) }.to raise_error(Errno::EACCES)

      File.chmod(0o644, file.path) # Restore permissions for cleanup
      file.unlink
    end
  end
end