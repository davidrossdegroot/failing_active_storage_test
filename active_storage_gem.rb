# frozen_string_literal: true

require 'bundler/inline'

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  # Activate the gem you are reporting the issue against.
  gem 'rails', '6.1.3.2'
  gem 'pg', '~> 1.2.0'
  gem 'aws-sdk-s3', '1.48.0'
  gem 'aws-sdk-sqs', '1.22.0'
  gem 'dotenv-rails'
  gem 'pry-byebug', '~> 3.9.0'
  gem 'pry-rails', '~> 0.3.4'
end

require 'active_record/railtie'
require 'active_storage/engine'
require 'tmpdir'

class TestApp < Rails::Application
  config.root = __dir__
  config.hosts << 'example.org'
  config.eager_load = false
  config.session_store :cookie_store, key: 'cookie_store_key'
  secrets.secret_key_base = 'secret_key_base'

  config.logger = Logger.new($stdout)
  Rails.logger  = config.logger
  config.active_storage.service = :amazon
  config.active_storage.service_configurations = {
    amazon: {
      service: 'S3',
      access_key_id: "our_key",
      secret_access_key: "our_secret",
      kms_key_id: "kms_key",
      region: "us-east-1",
      bucket: "bucket",
      http_open_timeout: 15,
      http_read_timeout: 60,
      http_wire_trace: true
    }
  }
end

require 'active_storage/service/s3_service'

# This is here because active storage s3 does not support
# client side encryption
module ActiveStorage
  class Service::S3Service < Service
    def initialize(bucket:, upload: {}, public: false, **options)
      super()
      client = Aws::S3::Encryption::Client.new(**options)
      @client = Aws::S3::Resource.new(client: client)
      @bucket = @client.bucket(bucket)

      @multipart_upload_threshold = upload.delete(:multipart_threshold) || 100.megabytes
      @public = public

      @upload_options = upload
      @upload_options[:acl] = "public-read" if public?
    end
  end
end

Rails.application.initialize!

require ActiveStorage::Engine.root.join('db/migrate/20170806125915_create_active_storage_tables.rb').to_s

ActiveRecord::Schema.define do
  CreateActiveStorageTables.new.change # can comment this out if you've already got the table

  create_table :users, force: true
end

class User < ActiveRecord::Base
  has_one_attached :profile
end

require 'minitest/autorun'

class BugTest < Minitest::Test
  def test_upload_and_download
    user = User.create!(
      profile: {
        content_type: 'text/plain',
        filename: 'dummy.txt',
        io: ::StringIO.new('dummy')
      }
    )

    assert_equal 'dummy', user.profile.download
  end
end
