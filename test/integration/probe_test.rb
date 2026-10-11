require "test_helper"

class ProbeTest < ActionDispatch::IntegrationTest
  HA_SETTINGS = { "HA_URL" => "http://ha.example:8123", "HA_TOKEN" => "token", "HA_PROBE_ENTITY" => "sensor.probe" }.freeze

  setup do
    @saved_env = HA_SETTINGS.keys.index_with { |key| ENV[key] }
    @saved_fetcher = Probe.fetcher
  end

  teardown do
    @saved_env.each { |key, value| ENV[key] = value }
    Probe.fetcher = @saved_fetcher
  end

  test "returns the probe's current value and when it last reported" do
    configure
    answer_with 200, { state: "33.54", last_reported: "2026-10-11T18:04:05+00:00" }.to_json

    get probe_path

    assert_response :success
    assert_equal 33.5, response.parsed_body["value"]
    assert_equal Time.utc(2026, 10, 11, 18, 4, 5), Time.zone.parse(response.parsed_body["reported_at"])
  end

  test "asks Home Assistant for the configured entity with the token" do
    configure
    asked = nil
    Probe.fetcher = ->(uri, token) {
      asked = [ uri.to_s, token ]
      fake_response(200, { state: "40", last_updated: Time.current.iso8601 }.to_json)
    }

    get probe_path

    assert_equal [ "http://ha.example:8123/api/states/sensor.probe", "token" ], asked
  end

  test "an unavailable probe is an error, not a zero" do
    configure
    answer_with 200, { state: "unavailable", last_reported: Time.current.iso8601 }.to_json

    get probe_path

    assert_response :service_unavailable
    assert_equal "The probe is unavailable", response.parsed_body["error"]
  end

  test "a Home Assistant failure is reported" do
    configure
    answer_with 401, "{}"

    get probe_path

    assert_response :service_unavailable
    assert_equal "Home Assistant answered 401", response.parsed_body["error"]
  end

  test "an unreachable Home Assistant is reported" do
    configure
    Probe.fetcher = ->(*) { raise Errno::EHOSTUNREACH }

    get probe_path

    assert_response :service_unavailable
    assert_match "Couldn't reach Home Assistant", response.parsed_body["error"]
  end

  test "without configuration there is no button and the endpoint says why" do
    HA_SETTINGS.each_key { |key| ENV.delete(key) }

    get pot_path(pots(:fern))
    assert_no_match "Get from HA", response.body

    get probe_path
    assert_response :service_unavailable
    assert_equal "Home Assistant isn't configured", response.parsed_body["error"]
  end

  test "with configuration the pot page offers the button" do
    configure

    get pot_path(pots(:fern))

    assert_match "Get from HA", response.body
  end

  test "a reading recorded from the probe keeps its source" do
    post pot_moisture_readings_path(pots(:fern)), params: { moisture_reading: { value: 33.5, source: "zigbee" } }

    assert_equal "zigbee", pots(:fern).moisture_readings.first.source
  end

  private

  def configure = HA_SETTINGS.each { |key, value| ENV[key] = value }

  def answer_with(code, body)
    Probe.fetcher = ->(*) { fake_response(code, body) }
  end

  def fake_response(code, body)
    klass = Net::HTTPResponse::CODE_TO_OBJ.fetch(code.to_s)
    klass.new("1.1", code.to_s, "").tap do |response|
      response.instance_variable_set(:@body, body)
      response.instance_variable_set(:@read, true)
    end
  end
end
