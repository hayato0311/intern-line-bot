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

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      head 470
    end

    prefectures = [
      '北海道','青森県','岩手県','宮城県','秋田県','山形県','福島県','茨城県','栃木県','群馬県','埼玉県','千葉県','東京都','神奈川県','新潟県','富山県',
      '石川県','福井県','山梨県','長野県','岐阜県','静岡県','愛知県','三重県','滋賀県','京都府','大阪府','兵庫県','奈良県','和歌山県','鳥取県','島根県',
      '岡山県','広島県','山口県','徳島県','香川県','愛媛県','高知県','福岡県','佐賀県','長崎県','熊本県','大分県','宮崎県','鹿児島県','沖縄県'
    ]

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
          if event.message['text'].in?(prefectures)
            uri = URI.parse('https://covid19-japan-web-api.now.sh/api/v1/prefectures')
            https = Net::HTTP.new(uri.host, uri.port);
            https.use_ssl = uri.scheme === "https"

            headers = { "Content-Type" => "application/json" }
            request = Net::HTTP::Get.new(uri.path)
            request.initialize_http_header(headers)
            response = https.request(request)

            covid_json = response.read_body
            covid = JSON.parse(covid_json)
            prefecture_id = prefectures.find_index { |n| n ==  event.message['text']}
            
            update_date = covid[prefecture_id]["last_updated"]["cases_date"]
            update_date = update_date.to_s
            update_date_year = update_date[0..3]
            update_date_month = update_date[4..5]
            update_date_day = update_date[6..]
            
            infected = covid[prefecture_id]["cases"] - covid[prefecture_id]["discharge"] - covid[prefecture_id]["deaths"]
            
            message['text'] = "#{event.message['text']}\n最終更新日\n#{update_date_year}/#{update_date_month}/#{update_date_day}\n現在の感染者数\n#{infected}人\n重症者数\n#{covid[prefecture_id]["severe"]}人\n死亡者数\n#{covid[prefecture_id]["deaths"]}人\n累計感染者数\n#{covid[prefecture_id]["cases"]}人"
          end
        end
        client.reply_message(event['replyToken'], message)
      end
    }
    head :ok
  end
end
