require 'openssl'
require 'base64'

class Citadel
  class CitadelError < Exception; end

  module Decrypt
    extend self

    def new(encrypted, key)
      begin
        cipher = OpenSSL::Cipher.new('aes-256-cbc')
        cipher.decrypt
        cipher.key = key

        return cipher.update(Base64.decode64(encrypted)) + cipher.final
      rescue Exception => e
        raise CitadelError, "Unable to decrypt: #{e}"
      end
    end

  end
end
