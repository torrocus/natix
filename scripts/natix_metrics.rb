require 'bigdecimal'
require 'bigdecimal/util'
require 'csv'
require 'date'
require 'json'
require 'net/http'
require 'uri'

CSV_FILE = 'natix_metrics.csv'
CSV_HEADERS = [
  'date',
  'totalKm',
  'totalDetections',
  'totalUsers',
  'countries',
  'natixBurned'
].freeze

OFFICIAL_NATIX_URL = 'https://www.natix.network/'
NATIX_NETWORK_METRICS_URL = 'https://coverage.natix.network/coverage/v1/metrics/global'

USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36'

# Method to append new data to the CSV file
def append_to_csv(data)
  is_file_empty = !File.exist?(CSV_FILE) || File.size?(CSV_FILE).nil?

  CSV.open(CSV_FILE, 'a+', headers: true) do |csv|
    csv << CSV_HEADERS if is_file_empty
    csv << CSV_HEADERS.map { |h| data[h] }
  end
end

def fetch_url(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 10
  http.read_timeout = 10
  http.use_ssl = true if uri.scheme == 'https'

  request = Net::HTTP::Get.new(uri.request_uri)
  request['User-Agent'] = USER_AGENT
  request['Accept'] = '*/*'
  request['Referer'] = 'https://www.natix.network/'
  request['Origin'] = 'https://www.natix.network'

  response = http.request(request)
  response.body
end

# Method to check the last entry in the CSV file
def last_csv_date
  return nil unless File.exist?(CSV_FILE) && File.size?(CSV_FILE)
  
  CSV.open(CSV_FILE, headers: true) do |csv|
    csv.to_a.last&.[]('date')
  end
end

def last_natix_burned
  return nil unless File.exist?(CSV_FILE) && File.size?(CSV_FILE)

  CSV.open(CSV_FILE, headers: true) do |csv|
    csv.to_a.last&.[]('natixBurned')
  end
end

def validate_csv_schema!
  return unless File.exist?(CSV_FILE)

  headers = CSV.open(CSV_FILE, headers: true, &:first)&.headers
  abort 'CSV header mismatch' if headers && headers != CSV_HEADERS
end

validate_csv_schema!

today = Time.now.utc.to_date.to_s
exit if last_csv_date == today

# Warm-up request to mimic browser behavior (not strictly required)
fetch_url(OFFICIAL_NATIX_URL)
json_response = fetch_url(NATIX_NETWORK_METRICS_URL)

raw = JSON.parse(json_response)
metrics = raw['result']
abort 'Invalid API response' unless metrics.is_a?(Hash)

natix_burned = BigDecimal(metrics['natixBurned'].to_s)
               .round(8)
               .to_s('F')

last_burn = last_natix_burned
abort 'natixBurned decreased' if last_burn && BigDecimal(natix_burned) < BigDecimal(last_burn)

data = {
  'date' => today,
  'totalKm' => metrics['kmMapped'],
  'totalDetections' => metrics['detections'],
  'totalUsers' => metrics['drivers'],
  'countries' => metrics['countries'],
  'natixBurned' => natix_burned
}

append_to_csv(data)

