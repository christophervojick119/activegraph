module Neo4j
  # To contain any base login for ActiveNode/ActiveRel which
  # is external to the main classes
  module ActiveBase
    at_exit do
      @driver&.close
    end

    class << self
      # private?
      def current_driver
        (@driver ||= establish_driver).tap do |driver|
          fail 'No driver defined!' if driver.nil?
        end
      end

      def on_establish_driver(&block)
        @establish_driver_block = block
      end

      def establish_driver
        @establish_driver_block.call if @establish_driver_block
      end

      def new_driver(url, options = {})
        verbose_query_logs = Neo4j::Config.fetch(:verbose_query_logs, false)
        Neo4j::Core::Driver
          .new(url, options, verbose_query_logs: verbose_query_logs)
      end

      def transaction
        current_transaction || Transaction
      end

      def query(*args)
        transaction.query(*args)
      end

      # Should support setting driver via config options
      def driver=(driver)
        @driver&.close
        @driver = driver
      end

      def run_transaction(run_in_tx = true)
        Transaction.run(current_driver, run_in_tx) do |tx|
          yield tx
        end
      end

      def new_transaction
        validate_model_schema!
        Neo4j::Transaction.new
      end

      def new_query(options = {})
        validate_model_schema!
        Neo4j::Core::Query.new({driver: current_driver}.merge(options))
      end

      def magic_query(*args)
        if args.empty? || args.map(&:class) == [Hash]
          ActiveBase.new_query(*args)
        else
          ActiveBase.current_driver.query(*args)
        end
      end

      def current_transaction
        validate_model_schema!
        Transaction.root
      end

      def label_object(label_name)
        Neo4j::Core::Label.new(label_name)
      end

      def logger
        @logger ||= (Neo4j::Config[:logger] || ActiveSupport::Logger.new(STDOUT))
      end

      private

      def validate_model_schema!
        Neo4j::ModelSchema.validate_model_schema! unless Neo4j::Migrations.currently_running_migrations
      end
    end
  end
end
