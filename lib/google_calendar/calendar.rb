require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'date'
require 'fileutils'

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
APPLICATION_NAME = 'Google Calendar API Ruby Quickstart'.freeze
CREDENTIALS_PATH = 'credentials.json'.freeze
# The file token.yaml stores the user's access and refresh tokens, and is
# created automatically when the authorization flow completes for the first
# time.
TOKEN_PATH = 'token.yaml'.freeze
SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts 'Open the following URL in the browser and enter the ' \
         "resulting code after authorization:\n" + url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end

# Initialize the API
service = Google::Apis::CalendarV3::CalendarService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

# Fetch the next 10 events for the user
# calendar_id = 'primary'
calendar_id = 'de0a8jsvche186m2p4goa9jgnr06713r@import.calendar.google.com'
response = service.list_events(calendar_id,
                               max_results: 10,
                               single_events: true,
                               order_by: 'startTime',
                               time_min: DateTime.now.rfc3339)


puts 'Upcoming events:'
puts 'No upcoming events found' if response.items.empty?
response.items.each do |event|
  start = event.start.date || event.start.date_time
  end_date = event.end.date || event.end.date_time
  puts "Not available: (#{start} - #{end_date})"
end

puts "#{service.list_calendar_lists.inspect}"

unavailable_dates = response
## update public availibility calendar:

availability_calendar_id = 'apartmentstino@gmail.com'

unavailable_dates.items.each do |event|
  start_date = event.start.date || event.start.date_time
  end_date = event.end.date || event.end.date_time

  event = Google::Apis::CalendarV3::Event.new(
    # summary: 'Google I/O 2015',
    # location: '800 Howard St., San Francisco, CA 94103',
    # description: 'A chance to hear more about Google\'s developer products.',
    start: {
      date_time: '#{start_date}'
      # time_zone: 'America/Los_Angeles',
    },
    end: {
      date_time: '#{end_date}'
      # time_zone: 'America/Los_Angeles',
    },
    # recurrence: [
    #   'RRULE:FREQ=DAILY;COUNT=2'
    # ],
    # attendees: [
    #   {email: 'lpage@example.com'},
    #   {email: 'sbrin@example.com'},
    # ],
    # reminders: {
    #   use_default: false,
    #   overrides: [
    #     {method' => 'email', 'minutes: 24 * 60},
    #     {method' => 'popup', 'minutes: 10},
    #   ],
    # },
  )

  result = service.insert_event(availability_calendar_id, event)
  puts "Event created: #{result.html_link}"
end