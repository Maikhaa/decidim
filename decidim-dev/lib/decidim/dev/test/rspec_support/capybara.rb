# frozen_string_literal: true

require "selenium-webdriver"

module Decidim
  # Helpers meant to be used only during capybara test runs.
  module CapybaraTestHelpers
    def switch_to_host(host = "lvh.me")
      raise "Can't switch to a custom host unless it really exists. Use `whatever.lvh.me` as a workaround." unless /lvh\.me$/.match?(host)

      app_host = (host ? "http://#{host}" : nil)
      Capybara.app_host = app_host
    end

    def switch_to_default_host
      Capybara.app_host = nil
    end
  end
end

#
# Monkeypatch to try to fix capybara server boot flakyness
#
module Capybara
  class Server
    def wait_for_pending_requests
      start_time = Capybara::Helpers.monotonic_time
      while pending_requests?
        raise "Requests did not finish in 60 seconds" if (Capybara::Helpers.monotonic_time - start_time) > 60

        sleep 0.01
      end
    end

    def boot
      unless responsive?
        Capybara::Server.ports[port_key] = port

        @server_thread = Thread.new do
          Capybara.server.call(middleware, port, host)
        end

        start_time = Capybara::Helpers.monotonic_time
        until responsive?
          raise "Rack application timed out during boot" if (Capybara::Helpers.monotonic_time - start_time) > 60

          @server_thread.join(0.1)
        end
      end

      self
    end
  end
end

Capybara.register_driver :headless_chrome do |app|
  options = ::Selenium::WebDriver::Chrome::Options.new
  options.args << "--headless"
  options.args << "--no-sandbox"
  options.args << "--window-size=1024,768"

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options
  )
end

Capybara.server = :puma, { Silent: true }

Capybara.asset_host = "http://localhost:3000"

Capybara.server_errors = [SyntaxError, StandardError]

RSpec.configure do |config|
  config.before :each, type: :system do
    driven_by(:headless_chrome)
    switch_to_default_host
  end

  config.before :each, driver: :rack_test do
    driven_by(:rack_test)
  end

  config.around :each, :slow do |example|
    max_wait_time_for_slow_specs = 7

    using_wait_time(max_wait_time_for_slow_specs) do
      example.run
    end
  end

  config.include Decidim::CapybaraTestHelpers, type: :system
  config.include Devise::Test::IntegrationHelpers, type: :system
end
