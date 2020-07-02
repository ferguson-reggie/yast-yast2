# ------------------------------------------------------------------------------
# Copyright (c) 2017-2020 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "uri"
require "yast"
require "delegate"

module Y2Packager
  # This class represents a libzypp URL
  #
  # Libzypp URLs do not conform to rfc3986 because they can include the so-called
  # Repository Variables. Those vars can have several formats like $variable,
  # ${variable}, ${variable-word} or ${variable+word}. They can appear in any
  # component of the URL (host, path, port...) except in scheme, user or password.
  #
  # See https://doc.opensuse.org/projects/libzypp/HEAD/zypp-repovars.html
  #
  # The current implementation relies on SimpleDelegator to expose all the methods
  # of an underlying URI object, so objects of this class can be used as a direct
  # replacement in places that used to use URI, like {Y2Packager::Repository#raw_url}
  #
  class ZyppUrl < SimpleDelegator
    Yast.import "Pkg"

    # Repository schemes considered local (see #local?)
    # https://github.com/openSUSE/libzypp/blob/a7a038aeda1ad6d9e441e7d3755612aa83320dce/zypp/Url.cc#L458
    LOCAL_SCHEMES = [:cd, :dvd, :dir, :hd, :iso, :file].freeze

    # Constructor
    #
    # @param url [String, ZyppUrl, URI::Generic]
    def initialize(url)
      __setobj__(URI(repovars_escape(url.to_s)))
    end

    # @return [URI::Generic]
    def uri
      __getobj__
    end

    alias_method :to_uri, :uri

    # Constructs String from the URL
    #
    # @return [String]
    def to_s
      repovars_unescape(uri.to_s)
    end

    # See URI::Generic#hostname
    #
    # @return [String]
    def hostname
      repovars_unescape(uri.hostname)
    end

    # See URI::Generic#hostname
    #
    # TODO: escaping does not work here because the port wouldn't accept the
    # escaped characters either. We likely need to modify the regexp used by
    # URI to parse/validate the port
    #
    # @return [String]
    def port
      repovars_unescape(uri.port)
    end

    # See URI::Generic#path
    #
    # @return [String]
    def path
      repovars_unescape(uri.path)
    end

    # See URI::Generic#path
    #
    # Offered for completeness, even if the query component makes very little
    # sense in a zypper URL.
    #
    # @return [String]
    def query
      repovars_unescape(uri.query)
    end

    # Whether the URL is local
    #
    # @return [Boolean] true if the URL is considered local; false otherwise
    def local?
      LOCAL_SCHEMES.include?(scheme&.to_sym)
    end

    # Expanded version of the URL in which the repository vars has been replaced
    # by their value
    #
    # @return [ZyppUrl] an URL that is expected to conform to rfc3986
    def expanded
      ZyppUrl.new(Yast::Pkg.ExpandedUrl(to_s))
    end

    # String representation of the state of the object
    #
    # @return [String]
    def inspect
      # Prevent SimpleDelegator from forwarding this to the wrapped URI object
      "#<#{self.class}:#{object_id}} @uri=#{uri.inspect}>"
    end

    # Compares two URLs
    #
    # NOTE: this considers an URI::Generic object to be equal if it represents
    # the same URL. That should increase a bit the robustness when a ZyppUrl
    # object is introduced to replace an existing URI one.
    def ==(other)
      if other.is_a?(URI::Generic)
        uri == other
      elsif other.class == self.class
        uri == other.uri
      else
        false
      end
    end

    # @see #==
    alias_method :eql?, :==

  private

    # Preprocess a string so it can be accepted as a valid URI
    #
    # Escaping and unescaping the invalid characters is implemented as an
    # alternative to the solution that may look more obvious and elegant:
    # configuring the parser of URI to accept those characters. Done this way
    # because configuring the parser implies dealing with very complex regexps,
    # which is not only risky but would also prevent us from benefiting from
    # future improvements in the Ruby's URI regexps.
    #
    # @param str [String] original string that may include repo vars
    # @return [String]
    def repovars_escape(str)
      str.gsub("{", "%7B").gsub("}", "%7D")
    end

    # @see #repovars_escape
    def repovars_unescape(str)
      str.gsub("%7B", "{").gsub("%7D", "}")
    end
  end
end
