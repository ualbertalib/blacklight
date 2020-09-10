module Blacklight
  class SolrRepository < AbstractRepository
    unless defined? RSolr
      # Deprecation.warn self, "RSolr should be in your gemfile. Blacklight 6.0 will not load rsolr by default"
      require 'rsolr'
    end

    extend Deprecation
    self.deprecation_horizon = 'blacklight 6.0'
    ##
    # Find a single solr document result (by id) using the document configuration
    # @param [String] document's unique key value
    # @param [Hash] additional solr query parameters
    def find id, params = {}
      doc_params = params.reverse_merge(blacklight_config.default_document_solr_params)
                         .reverse_merge(qt: blacklight_config.document_solr_request_handler)
                         .merge(blacklight_config.document_unique_id_param => id)

      solr_response = send_and_receive blacklight_config.document_solr_path || blacklight_config.solr_path, doc_params
      raise Blacklight::Exceptions::RecordNotFound.new if solr_response.documents.empty?
      solr_response
    end

    ##
    # Execute a search query against solr
    # @param [Hash] solr query parameters
    def search params = {}
      send_and_receive blacklight_config.solr_path, params.reverse_merge(qt: blacklight_config.qt)
    end

    ##
    # Execute a solr query
    # @see [RSolr::Client#send_and_receive]
    # @overload find(solr_path, params)
    #   Execute a solr query at the given path with the parameters
    #   @param [String] solr path (defaults to blacklight_config.solr_path)
    #   @param [Hash] parameters for RSolr::Client#send_and_receive
    # @overload find(params)
    #   @param [Hash] parameters for RSolr::Client#send_and_receive
    # @return [Blacklight::SolrResponse] the solr response object
    def send_and_receive(path, solr_params = {})
      benchmark("Solr fetch", level: :debug) do
        key = blacklight_config.http_method == :post ? :data : :params
        res = connection.send_and_receive(path, {key=>solr_params.to_hash, method: blacklight_config.http_method})

        solr_response = blacklight_config.response_model.new(res, solr_params, document_model: blacklight_config.document_model, blacklight_config: blacklight_config)

        Blacklight.logger.debug("Solr query: #{blacklight_config.http_method} #{path} #{solr_params.to_hash.inspect}")
        Blacklight.logger.debug("Solr response: #{solr_response.inspect}") if defined?(::BLACKLIGHT_VERBOSE_LOGGING) and ::BLACKLIGHT_VERBOSE_LOGGING
        solr_response
      end
    rescue Errno::ECONNREFUSED => e
      raise Blacklight::Exceptions::ECONNREFUSED.new("Unable to connect to Solr instance using #{connection.inspect}: #{e.inspect}")
    rescue RSolr::Error::Http => e
      raise Blacklight::Exceptions::InvalidRequest.new(e.message)
    end

    def blacklight_solr
      connection
    end
    deprecation_deprecate blacklight_solr: :connection

    def blacklight_solr=(conn)
      self.connection = conn
    end
    deprecation_deprecate :blacklight_solr= => :connection=

    def blacklight_solr_config
      connection_config
    end
    deprecation_deprecate blacklight_solr_config: :connection_config

    protected

      def build_connection
        RSolr.connect(connection_config)
      end
  end
end
