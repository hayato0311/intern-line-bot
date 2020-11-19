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

  LINK = {
    '東京都':{
      hotel: 'https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=tokyo&f_shou=tokyo&f_sai=&f_dist=&f_cd=03&f_campaign=20allgoto2009dh-02&f_layout=list',
      spot: 'https://travel.rakuten.co.jp/mytrip/ranking/spot-tokyo/',
    },
  }
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
          uri = URI.parse(API_URL)
          response = Net::HTTP.get_response(uri)
          body = response.read_body
          
          covid = JSON.parse(body)
          prefecture = event.message['text']
          if prefecture != '北海道'
            prefecture = prefecture.chop
          end

          covid_prefecture = covid.find { |data| data['name_ja'] == prefecture }
          if covid_prefecture
            update_date = covid_prefecture["last_updated"]["cases_date"]
            update_date = update_date.to_s
            update_date = Date.parse(update_date)
            
            message = message_template(
              event.message['text'], 
              update_date.strftime("%Y/%m/%d"), 
              infected_population(covid_prefecture).to_s,
              covid_prefecture["severe"].to_s, 
              covid_prefecture["deaths"].to_s,
              covid_prefecture["cases"].to_s
            )
          end
        end        
        client.reply_message(event['replyToken'], message)
      end
    }
    head :ok
  end

  def message_template(prefecture, date, infected, severe, deaths, cases)
    {
      type: "flex",
      altText: prefecture + "のコロナ情報",
      contents: {
        type: "bubble",
        body: {
          type: "box",
          layout: "vertical",
          spacing: "md",
          contents: [
            {
              type: "text",
              text: prefecture,
              margin: "none",
              size: "xxl",
              align: "center",
              weight: "bold",
              color: "#4FA74A"
            },
            {
              type: "text",
              text: date + " 更新" ,
              margin: "none",
              size: "sm",
              align: "center",
              color: "#AAAAAA"
            },
            {
              type: "separator"
            },
            {
              type: "box",
              layout: "horizontal",
              contents: [
                {
                  type: "text",
                  text: "感染中",
                  size: "sm",
                  align: "center",
                  gravity: "center",
                  weight: "bold",
                  color: "#000000"
                },
                {
                  type: "text",
                  text: infected + "人",
                  size: "sm",
                  align: "center",
                  gravity: "center",
                  weight: "bold",
                  color: "#C82525"
                },
                {
                  type: "text",
                  text: "重症",
                  size: "sm",
                  align: "center",
                  gravity: "center",
                  weight: "bold",
                  color: "#000000"
                },
                {
                  type: "text",
                  text: severe + "人",
                  size: "sm",
                  align: "center",
                  gravity: "center",
                  weight: "bold",
                  color: "#C82525"
                }
              ]
            },
            {
              type: "box",
              layout: "baseline",
              contents: [
                {
                  type: "text",
                  text: "累計",
                  size: "sm",
                  align: "center",
                  gravity: "center",
                  weight: "bold",
                  color: "#000000"
                },
                {
                  type: "text",
                  text: cases + "人",
                  size: "sm",
                  align: "center",
                  gravity: "center",
                  weight: "bold",
                  color: "#C82525"
                },
                {
                  type: "text",
                  text: "死亡",
                  size: "sm",
                  align: "center",
                  gravity: "center",
                  weight: "bold",
                  color: "#000000"
                },
                {
                  type: "text",
                  text: deaths + "人",
                  size: "sm",
                  align: "center",
                  gravity: "center",
                  weight: "bold",
                  color: "#C82525"
                }
              ]
            },
            {
              type: "separator"
            },
            {
              type: "box",
              layout: "horizontal",
              contents: [
                {
                  type: "button",
                  action: {
                    type: "uri",
                    label: "ホテル・旅館",
                    uri: LINK[:'東京都'][:hotel]
                  },
                },
                {
                  type: "button",
                  action: {
                    type: "uri",
                    label: "観光地",
                    uri: LINK[:'東京都'][:spot]
                  },
                },
              ]
            },
          ]
        }
      }
    }
  end

  private
  def infected_population(covid_info)
    covid_info["cases"] - covid_info["discharge"] - covid_info["deaths"]
  end

end
