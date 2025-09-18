require 'csv'
require 'date'
require 'json'
require 'net/http'
require 'uri'

CSV_FILE = 'nubila_node_count.csv'

NUBILA_NODE_COUNT_URL = 'https://nubila-server-prd-wmlxwgn2ua-uc.a.run.app/v1/node_count'

USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36'

# Method to append new data to the CSV file
def append_to_csv(data)
  is_file_empty = !File.exist?(CSV_FILE) || File.size?(CSV_FILE).nil?

  CSV.open(CSV_FILE, 'a+', headers: true) do |csv|
    csv << ['date', 'totalNode'] if is_file_empty
    csv << [data['date'], data['totalNode']]
  end
end

def fetch_url(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'

  request = Net::HTTP::Get.new(uri.request_uri)
  request['User-Agent'] = USER_AGENT

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

today = Date.today.to_s
exit if last_csv_date == today

json_response = fetch_url(NUBILA_NODE_COUNT_URL)

data = JSON.parse(json_response)
data['date'] = today
append_to_csv(data)
