require "net/http"

# The roving soil probe, read through Home Assistant rather than from the
# device directly — HA already owns the Zigbee pairing. Unconfigured is a
# normal state: the app works without it, and the pot page just omits the
# button that would call it.
class Probe
  class Unavailable < StandardError; end

  Reading = Data.define(:value, :reported_at)

  # Swappable so tests can stand in for Home Assistant without a network.
  class_attribute :fetcher, default: ->(uri, token) {
    request = Net::HTTP::Get.new(uri, "Authorization" => "Bearer #{token}")
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                    open_timeout: 3, read_timeout: 5) { |http| http.request(request) }
  }

  def self.configured? = settings.values.all?(&:present?)

  def self.settings
    { url: ENV["HA_URL"], token: ENV["HA_TOKEN"], entity: ENV["HA_PROBE_ENTITY"] }
  end

  def self.read
    raise Unavailable, "Home Assistant isn't configured" unless configured?

    url, token, entity = settings.values_at(:url, :token, :entity)
    response = fetcher.call(URI.join(url, "/api/states/#{entity}"), token)
    raise Unavailable, "Home Assistant answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    state = JSON.parse(response.body)
    value = Float(state["state"], exception: false)
    raise Unavailable, "The probe is #{state["state"]}" if value.nil?

    Reading.new(value: value.round(1), reported_at: Time.zone.parse(state["last_reported"] || state["last_updated"]))
  rescue SystemCallError, Timeout::Error, SocketError, JSON::ParserError => error
    raise Unavailable, "Couldn't reach Home Assistant (#{error.class.name.demodulize})"
  end
end
