# frozen_string_literal: true

require "lograge"

describe "Browser page view logging" do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:log_io) { StringIO.new }

  before do
    ApplicationRequest.enable
    CachedCounting.reset
    CachedCounting.enable

    # Enables the meta tag that the SPA reads to populate session id, url, and
    # referrer on the first AJAX after a route navigation.
    SiteSetting.trigger_browser_pageview_events = true

    Lograge.formatter = Lograge::Formatters::Logstash.new
    Lograge.log_level = :debug
    Lograge.custom_options =
      lambda do |event|
        exceptions = %w[controller action format id]
        params = event.payload[:params].except(*exceptions)
        { params: params.to_query }
      end
    Lograge::LogSubscribers::ActionController.attach_to(:action_controller)

    log_io.truncate(0)
    log_io.rewind
    logger = Logger.new(log_io)
    logger.formatter = ->(_severity, _time, _progname, msg) { "#{msg}\n" }
    Lograge.logger = logger
  end

  after do
    Lograge::LogSubscribers::ActionController.detach_from(:action_controller)
    CachedCounting.reset
    ApplicationRequest.disable
    CachedCounting.disable
  end

  def bpv_entries
    log_io.rewind
    log_io
      .read
      .lines
      .reject { |l| l.strip.empty? }
      .map { |line| JSON.parse(line) }
      .select { |entry| entry["controller"] == "PageviewController" }
  end

  it "writes BPV entries when an anonymous user navigates to a topic" do
    visit "/"
    find(".topic-list-item .raw-topic-link[data-topic-id='#{topic.id}']").click

    try_until_success(timeout: 10) do
      # The first AJAX request after a route navigation carries the full BPV
      # headers (url, referrer, session_id, topic_id). Subsequent AJAX calls
      # during the same page load only carry the Discourse-Track-View flag.
      entry =
        bpv_entries.find do |e|
          e["action"] == "piggyback" && e["params"].to_s.include?("topic_id=#{topic.id}") &&
            e["params"].to_s.include?("url=")
        end
      expect(entry).to be_present
      expect(entry["path"]).to eq("/pageview")
      expect(entry["params"]).to include("session_id=")
    end
  end

  it "writes a beacon entry when use_beacon_for_browser_page_views is enabled" do
    SiteSetting.use_beacon_for_browser_page_views = true

    visit "/"

    try_until_success do
      beacon = bpv_entries.find { |e| e["action"] == "beacon" }
      expect(beacon).to be_present
      expect(beacon["path"]).to eq("/srv/pv")
      expect(beacon["status"]).to eq(204)
    end
  end

  it "carries username at the top of the entry for a logged-in user" do
    user = Fabricate(:user)
    sign_in(user)

    visit "/"

    try_until_success do
      entry = bpv_entries.find { |e| e["action"] == "piggyback" }
      expect(entry).to be_present
      expect(entry["username"]).to eq(user.username)
    end
  end

  it "does not write a BPV entry for a crawler" do
    # Playwright's UA can't be changed mid-test; tag chrome as a crawler instead.
    SiteSetting.crawler_user_agents += "|chrome"

    visit "/"

    # Wait for any pageview-related traffic to settle then verify no BPV
    # entries were emitted for the crawler.
    try_until_success { CachedCounting.flush }
    expect(bpv_entries).to be_empty
  end

  it "does not write a BPV entry for an anonymous visit when login_required is on" do
    SiteSetting.login_required = true

    visit "/"

    try_until_success { CachedCounting.flush }
    expect(bpv_entries).to be_empty
  end
end
