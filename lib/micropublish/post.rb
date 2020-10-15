# frozen_string_literal: true

module Micropublish
  class Post
    attr_reader :type, :properties

    def initialize(type, properties)
      @type = type
      @properties = properties
    end

    def self.properties_from_params(params)
      props = {}
      params.keys.each do |param|
        next if params[param].nil? || params[param].empty? ||
                params[param] == ['']
        if param.start_with?('_')
          next
        elsif param == 'mp-syndicate-to'
          props[param] = params[param]
        elsif param == 'category'
          props['category'] = if params['category'].is_a?(Array)
                                params['category']
                              else
                                params['category'].split(/,\s?/)
                              end
        elsif param == 'content'
          props['content'] = Array(params[param])
        else
          props[param] = if params[param].is_a?(Array) &&
                            params[param][0].is_a?(String)
                           params[param][0].split(/\s+/)
                         else
                           Array(params[param])
                         end
        end
      end
      props
    end

    def validate_properties!(required = [])
      # ensure url arrays only contain urls
      %w[in-reply-to repost-of like-of bookmark-of syndication].each do |url_property|
        next unless @properties.key?(url_property)

        @properties[url_property].each do |url|
          next if Auth.valid_uri?(url)

          raise MicropublishError.new('post',
                                      "\"#{url}\" is not a valid URL. <code>#{url_property}</code> " \
                                      'accepts only one or more URLs separated by whitespace.')
        end
      end
      # check all required properties have been provided
      required.each do |property|
        next unless !@properties.key?(property) ||
                    (property == 'checkin' &&
                      (@properties['checkin'][0]['properties']['name'][0].empty? ||
                      @properties['checkin'][0]['properties']['latitude'][0].empty? ||
                      @properties['checkin'][0]['properties']['longitude'][0].empty?))

        raise MicropublishError.new('post',
                                    "<code>#{property}</code> is required for the form to be " \
                                    'submitted. Please enter a value for this property.')
      end
    end

    def h_type
      @type[0].gsub(/^h\-/, '')
    end

    def to_form_encoded
      props = Hash[@properties.map { |k, v| v.size > 1 ? ["#{k}[]", v] : [k, v] }]
      query = { h: h_type }.merge(props)
      URI.encode_www_form(query)
    end

    def to_json(pretty=false)
      hash = { type: @type, properties: @properties }
      pretty ? JSON.pretty_generate(hash) : hash.to_json
    end

    def diff_properties(submitted)
      diff = {
        replace: {},
        add: {},
        delete: []
      }
      diff_removed!(diff, submitted)
      diff_added!(diff, submitted)
      diff_replaced!(diff, submitted)
      diff
    end

    def diff_removed!(diff, submitted)
      @properties.keys.each do |prop|
        diff[:delete] << prop if !submitted.key?(prop) || submitted[prop].empty?
      end
      diff.delete(:delete) if diff[:delete].empty?
    end

    def diff_added!(diff, submitted)
      submitted.keys.each do |prop|
        next if @properties.key?(prop)

        diff[:add][prop] = if submitted[prop].is_a?(Array)
                             submitted[prop]
                           else
                             [submitted[prop]]
                           end
      end
      diff.delete(:add) if diff[:add].empty?
    end

    def diff_replaced!(diff, submitted)
      submitted.keys.each do |prop|
        next unless @properties.key?(prop) && @properties[prop] != submitted[prop]

        diff[:replace][prop] = if submitted[prop].is_a?(Array)
                                 submitted[prop]
                               else
                                 [submitted[prop]]
                               end
      end
      diff.delete(:replace) if diff[:replace].empty?
    end

    def entry_type
      if @properties.key?('rsvp') &&
         %w[yes no maybe interested].include?(@properties['rsvp'][0])
        'rsvp'
      elsif @properties.key?('in-reply-to') &&
            Auth.valid_uri?(@properties['in-reply-to'][0])
        'reply'
      elsif @properties.key?('repost-of') &&
            Auth.valid_uri?(@properties['repost-of'][0])
        'repost'
      elsif @properties.key?('like-of') &&
            Auth.valid_uri?(@properties['like-of'][0])
        'like'
      elsif @properties.key?('bookmark-of') &&
            Auth.valid_uri?(@properties['bookmark-of'][0])
        'bookmark'
      elsif @properties.key?('name') && !@properties['name'].empty? &&
            !content_start_with_name?
        'article'
      elsif @properties.key?('checkin')
        'checkin'
      else
        'note'
      end
    end

    def content_start_with_name?
      return unless @properties.key?('content') && @properties.key?('name')

      content = if @properties['content'][0].is_a?(Hash) &&
                   @properties['content'][0].key?('html')
                  @properties['content'][0]['html']
                else
                  @properties['content'][0]
                end
      content_tidy = content.strip.gsub(/\s+/, ' ')
      name_tidy = @properties['name'][0].strip.gsub(/\s+/, ' ')
      content_tidy.start_with?(name_tidy)
    end
  end
end
