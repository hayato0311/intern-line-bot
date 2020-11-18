require 'line/bot'
require "uri"
require "net/http"
require "json"

class WebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化

  PREFECTURES = [
    '北海道','青森県','岩手県','宮城県','秋田県','山形県','福島県','茨城県','栃木県','群馬県','埼玉県','千葉県','東京都','神奈川県','新潟県','富山県',
    '石川県','福井県','山梨県','長野県','岐阜県','静岡県','愛知県','三重県','滋賀県','京都府','大阪府','兵庫県','奈良県','和歌山県','鳥取県','島根県',
    '岡山県','広島県','山口県','徳島県','香川県','愛媛県','高知県','福岡県','佐賀県','長崎県','熊本県','大分県','宮崎県','鹿児島県','沖縄県'
  ]

  API_URL = 'https://covid19-japan-web-api.now.sh/api/v1/prefectures'

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
            uri = URI.parse(API_URL)
            response = Net::HTTP.get_response(uri)
            body = response.read_body
            
            covid = JSON.parse(body)
            prefecture = event.message['text']
            if prefecture != '北海道'
              prefecture = prefecture.chop
            end

            covid_prefecture = covid.find { |data| data['name_ja'] == prefecture }

            update_date = covid_prefecture["last_updated"]["cases_date"]
            update_date = update_date.to_s
            update_date = Date.parse(update_date)

            message['text'] = <<~EOS
              #{event.message['text']}
              最終更新日
              #{update_date.strftime("%Y/%m/%d")}
              現在の感染者数
              #{infected_population(covid_prefecture)}人
              重症者数
              #{covid_prefecture["severe"]}人
              死亡者数
              #{covid_prefecture["deaths"]}人
              累計感染者数
              #{covid_prefecture["cases"]}人
            EOS
          end
        end
        client.reply_message(event['replyToken'], message)
      end
    }
    head :ok
  end

  private
  def infected_population(covid_info)
    return covid_info["cases"] - covid_info["discharge"] - covid_info["deaths"]
  end

end
