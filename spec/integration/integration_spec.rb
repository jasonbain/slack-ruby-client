require 'slack'
require 'logger'

RSpec.describe 'integration test', skip: !ENV['SLACK_API_TOKEN'] && 'missing SLACK_API_TOKEN' do
  before do
    Thread.abort_on_exception = true
  end

  let(:logger) { Logger.new(STDOUT) }

  let(:queue) { Queue.new }

  let(:client) { Slack::RealTime::Client.new(token: ENV['SLACK_API_TOKEN']) }

  let(:connection) do
    # starts the client and pushes an item on a queue when connected
    client.start_async do |driver|
      driver.on :open do |data|
        logger.debug "connection.on :open, data=#{data}"
        queue.push nil
      end
    end
  end

  before do
    client.on :hello do
      logger.info "Successfully connected, welcome '#{client.self['name']}' to the '#{client.team['name']}' team at https://#{client.team['domain']}.slack.com."
    end

    client.on :close do
      # pushes another item to the queue when disconnected
      queue.push nil
    end
  end

  def start_server
    logger.debug '#start_server'
    # start server and wait for on :open
    c = connection
    logger.debug "connection is #{c}"
    queue.pop
  end

  def wait_for_server
    logger.debug '#wait_for_server'
    queue.pop
    logger.debug '#wait_for_server, joined'
  end

  def stop_server
    logger.debug '#stop_server'
    client.stop!
    logger.debug '#stop_server, stopped'
  end

  after do
    wait_for_server
  end

  context 'client connected' do
    before do
      start_server
    end

    it 'responds to message' do
      message = SecureRandom.hex

      client.on :message do |data|
        logger.debug data
        expect(data).to include('text' => message, 'subtype' => 'bot_message')
        logger.debug 'client.stop!'
        client.stop!
      end

      logger.debug "chat_postMessage, channel=@#{client.self['name']}, message=#{message}"
      client.web_client.chat_postMessage channel: "@#{client.self['name']}", text: message
    end
  end

  it 'gets hello' do
    client.on :hello do |data|
      logger.debug "client.on :hello, data=#{data}"
      client.stop!
    end

    start_server
  end
end
