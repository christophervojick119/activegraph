# To run coverage via travis
require 'coveralls'
Coveralls.wear!
require 'simplecov'
SimpleCov.start

# To run it manually via Rake
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
  SimpleCov.start
end

require 'bundler/setup'
require 'rspec'
require 'its'
require 'fileutils'
require 'tmpdir'
require 'logger'
require 'active_attr/rspec'

require 'neo4j-core'
require 'neo4j'
require 'unique_class'

require 'pry' if ENV['APP_ENV'] == 'debug'


class MockLogger
  def info(*_args)
  end
end

module Rails
  def self.logger
    MockLogger.new
  end
end


Dir["#{File.dirname(__FILE__)}/shared_examples/**/*.rb"].each { |f| require f }

EMBEDDED_DB_PATH = File.join(Dir.tmpdir, 'neo4j-core-java')

I18n.enforce_available_locales = false

module Neo4jSpecHelpers
  def create_embedded_session
    require 'neo4j-embedded/embedded_impermanent_session'
    session = Neo4j::Session.open(:impermanent_db, EMBEDDED_DB_PATH, auto_commit: true)
    session.start
  end

  def server_username
    ENV['NEO4J_USERNAME'] || 'neo4j'
  end

  def server_password
    ENV['NEO4J_PASSWORD'] || 'neo4jrb rules, ok?'
  end

  def basic_auth_hash
    {
      username: server_username,
      password: server_password
    }
  end

  def server_url
    ENV['NEO4J_URL'] || 'http://localhost:7474'
  end

  def create_server_session(options = {})
    Neo4j::Session.open(:server_db, server_url, {basic_auth: basic_auth_hash}.merge(options))
    delete_db # Should separate this out
  end

  def create_session
    if RUBY_PLATFORM == 'java'
      create_embedded_session
    else
      create_server_session
    end
  end

  def create_named_server_session(name, default = nil)
    Neo4j::Session.open_named(:server_db, name, default, server_url, basic_auth: basic_auth_hash)
  end

  def session
    Neo4j::Session.current
  end

  def log_queries!
    Neo4j::Server::CypherSession.log_with do |message|
      puts message
    end
  end
end

FileUtils.rm_rf(EMBEDDED_DB_PATH)

Dir["#{File.dirname(__FILE__)}/shared_examples/**/*.rb"].each { |f| require f }

def delete_db
  Neo4j::Session.current._query('MATCH (n) OPTIONAL MATCH (n)-[r]-() DELETE n,r')
end

Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each { |f| require f }

module ActiveNodeRelStubHelpers
  def stub_active_node_class(class_name, &block)
    stub_const class_name, active_node_class(class_name, &block)
  end

  def stub_active_rel_class(class_name, &block)
    stub_const class_name, active_rel_class(class_name, &block)
  end

  def stub_named_class(class_name, superclass = nil, &block)
    stub_const class_name, named_class(class_name, superclass, &block)
  end

  def active_node_class(class_name, &block)
    named_class(class_name) do
      include Neo4j::ActiveNode

      module_eval(&block) if block
    end
  end

  def active_rel_class(class_name, &block)
    named_class(class_name) do
      include Neo4j::ActiveRel

      module_eval(&block) if block
    end
  end

  def named_class(class_name, superclass = nil, &block)
    Class.new(superclass || Object) do
      @class_name = class_name
      class << self
        attr_reader :class_name
        alias_method :name, :class_name
      end

      module_eval(&block) if block
    end
  end
end

RSpec.configure do |c|
  c.include Neo4jSpecHelpers

  c.before(:all) do
    Neo4j::Session.current.close if Neo4j::Session.current
    create_session
  end

  c.before(:each) do
    Neo4j::Session._listeners.clear
    curr_session = Neo4j::Session.current
    curr_session || create_session
  end

  c.after(:each) do
    if Neo4j::Transaction.current
      puts 'WARNING forgot to close transaction'
      Neo4j::Transaction.current.close
    end
  end

  c.exclusion_filter = {
    api: lambda do |ed|
      RUBY_PLATFORM == 'java' && ed == :server
    end
  }

  c.include ActiveNodeRelStubHelpers
end
