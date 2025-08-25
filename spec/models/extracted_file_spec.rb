require 'rails_helper'

RSpec.describe ExtractedFile, type: :model do
  subject { build(:extracted_file) }

  describe "associations" do
    it { should belong_to(:download) }
    it { should have_one_attached(:file) }
    it { should have_many(:entities).dependent(:destroy) }

    describe "file attachment cleanup at record destroy" do
      subject { create(:extracted_file) }

      it "purges attached file when download is destroyed" do
        mock_file = StringIO.new("fake zip content")

        subject.file.attach(
          io: mock_file,
          filename: 'test.zip',
          content_type: 'application/zip'
        )

        file_blob = subject.file.blob

        expect { subject.destroy }
          .to have_enqueued_job(ActiveStorage::PurgeJob)
                .with(file_blob)
      end
    end
  end

  describe "validations" do
    it { should validate_presence_of(:path) }
    it { should validate_presence_of(:download) }

    context "uniqueness validation" do
      it "validates uniqueness of path scoped to download" do
        download = create(:download)
        create(:extracted_file, download: download, path: "test/file.csv")

        duplicate = build(:extracted_file, download: download, path: "test/file.csv")
        expect(duplicate).to be_invalid
        expect(duplicate.errors[:path]).to include("has already been taken")
      end

      it "allows same path for different downloads" do
        download1 = create(:download)
        download2 = create(:download)
        create(:extracted_file, download: download1, path: "test/file.csv")

        duplicate = build(:extracted_file, download: download2, path: "test/file.csv")
        expect(duplicate).to be_valid
      end
    end
  end

  describe "#file_name" do
    subject { build(:extracted_file, path: file_path) }

    context "with file extension" do
      let(:file_path) { "actors/PA123456.json" }

      it "returns filename without extension" do
        expect(subject.file_name).to eq("PA123456")
      end
    end

    context "with no extension" do
      let(:file_path) { "data/filename" }

      it "returns full filename" do
        expect(subject.file_name).to eq("filename")
      end
    end

    context "with nested path" do
      let(:file_path) { "deeply/nested/path/document.xml" }

      it "returns basename without extension" do
        expect(subject.file_name).to eq("document")
      end
    end
  end
end
