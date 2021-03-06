#
# Author:: Noah Kantrowitz <noah@coderanger.net>
#
# Copyright 2013, Balanced, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require 'digest'

class Citadel
  attr_reader :bucket, :access_key_id, :secret_access_key, :token, :encryption_key

  def initialize(node, bucket=nil)
    @node = node
    @bucket = bucket || node['citadel']['bucket']
    @encryption_key = node['citadel']['encryption_key']

    if node['citadel']['access_key_id']
      # Manually specified credentials
      @access_key_id = node['citadel']['access_key_id']
      @secret_access_key = node['citadel']['secret_access_key']
    elsif node['ec2'] && node['ec2']['iam'] && node['ec2']['iam']['security-credentials']
      # Creds loaded from EC2 metadata server
      # This doesn't yet handle expiration, but it should
      role_creds = node['ec2']['iam']['security-credentials'].values.first
      @access_key_id = role_creds['AccessKeyId']
      @secret_access_key = role_creds['SecretAccessKey']
      @token = role_creds['Token']
    else
      raise 'Unable to load secrets from S3, no S3 credentials found'
    end
  end

  def [](key)
    Chef::Log.debug("citadel: Retrieving #{@bucket}/#{key}")
    contents = Citadel::S3.get(@bucket, key, @access_key_id, @secret_access_key, @token).to_s
    if @encryption_key
      begin
        contents = Citadel::Decrypt.new(contents, @encryption_key)
      rescue CitadelError => e
        md5_key = Digest::MD5.new.hexdigest(@encryption_key)
        raise CitadelError, "Failed to decrypt S3 key #{key} (using encryption key with an MD5 starting with #{md5_key[0,6]}): #{e}"
      end
    end

    return contents
  end

  # Helper module for the DSL extension
  module ChefDSL
    def citadel(bucket=nil)
      Citadel.new(node, bucket)
    end
  end
end

# Patch our DSL extension into Chef
class Chef
  class Recipe
    include Citadel::ChefDSL
  end

  class Resource
    include Citadel::ChefDSL
  end

  class Provider
    include Citadel::ChefDSL
  end
end
