require 'line/bot'
require "uri"
require "net/http"
require "json"

class WebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
  
  def infected_population(covid_info)
    return covid_info["cases"] - covid_info["discharge"] - covid_info["deaths"]
  end

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      head 470
    end

    api_url = 'https://covid19-japan-web-api.now.sh/api/v1/prefectures'

    events = client.parse_events_from(body)
    events.each { |event|
      case event
      when Line::Bot::Event::Message
        message = {
          type: 'text',
          text: "都道府県名を入力してください。\n(例：福岡県)"
        }
        case event.type
        when Line::Bot::Event::MessageType::Text
          if event.message['text'].in?(PREFECTURES)
            uri = URI.parse(api_url)
            response = Net::HTTP.get_response(uri)

            covid_json = response.read_body
            covid = JSON.parse(covid_json)
            prefecture_id = PREFECTURES.find_index(event.message['text'])
            
            update_date = covid[prefecture_id]["last_updated"]["cases_date"]
            update_date = update_date.to_s
            update_date = Date.parse(update_date)
            
            infected = infected_population(covid[prefecture_id])

            message['text'] = <<~EOS
              #{event.message['text']}
              最終更新日
              #{update_date.year}/#{update_date.month}/#{update_date.day}
              現在の感染者数
              #{infected}人
              重症者数
              #{covid[prefecture_id]["severe"]}人
              死亡者数
              #{covid[prefecture_id]["deaths"]}人
              累計感染者数
              #{covid[prefecture_id]["cases"]}人
            EOS
          end
        end
        client.reply_message(event['replyToken'], message)
      end
    }
    head :ok
  end
end
