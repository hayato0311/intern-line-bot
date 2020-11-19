require 'line/bot'
require "uri"
require "net/http"
require "json"

class WebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化

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

            prefecture_data = prefectures_info.find {|data| data[:name] == event.message['text']}

            message = message_template(
              event.message['text'], 
              update_date.strftime("%Y/%m/%d"), 
              infected_population(covid_prefecture).to_s,
              covid_prefecture["severe"].to_s, 
              covid_prefecture["deaths"].to_s,
              covid_prefecture["cases"].to_s,
              prefecture_data[:links]
            )
          end
        end        
        client.reply_message(event['replyToken'], message)
      end
    }
    head :ok
  end

  private
  def infected_population(covid_info)
    covid_info["cases"] - covid_info["discharge"] - covid_info["deaths"]
  end

  def message_template(prefecture, date, infected, severe, deaths, cases, links)
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
                    uri: links[:hotel]
                  },
                },
                {
                  type: "button",
                  action: {
                    type: "uri",
                    label: "観光地",
                    uri: links[:spot]
                  },
                },
              ]
            },
          ]
        }
      }
    }
  end

  def prefectures_info
    [
      {
        name: '北海道',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=hokkaido&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-hokkaido/",
        }
      },
      {
        name: '青森県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=aomori&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-aomori/",
        }
      },
      {
        name: '岩手県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=iwate&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-iwate/",
        }
      },
      {
        name: '宮城県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=miyagi&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-miyagi/",
        }
      },
      {
        name: '秋田県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=akita&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-akita/",
        }
      },
      {
        name: '山形県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=yamagata&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-yamagata/",
        }
      },
      {
        name: '福島県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=hukushima&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-fukushima/",
        }
      },
      {
        name: '茨城県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=ibaragi&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-ibaraki/",
        }
      },
      {
        name: '栃木県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=tochigi&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-tochigi/",
        }
      },
      {
        name: '群馬県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=gunma&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-gunma/",
        }
      },
      {
        name: '埼玉県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=saitama&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-saitama/",
        }
      },
      {
        name: '千葉県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=tiba&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-chiba/",
        }
      },
      {
        name: '東京都',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=tokyo&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-tokyo/",
        }
      },
      {
        name: '神奈川県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=kanagawa&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-kanagawa/",
        }
      },
      {
        name: '新潟県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=niigata&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-niigata/",
        }
      },
      {
        name: '富山県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=toyama&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-toyama/",
        }
      },
      {
        name: '石川県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=ishikawa&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-ishikawa/",
        }
      },
      {
        name: '福井県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=hukui&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-fukui/",
        }
      },
      {
        name: '山梨県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=yamanasi&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-yamanashi/",
        }
      },
      {
        name: '長野県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=nagano&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-nagano/",
        }
      },
      {
        name: '岐阜県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=gihu&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-gifu/",
        }
      },
      {
        name: '静岡県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=shizuoka&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-shizuoka/",
        }
      },
      {
        name: '愛知県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=aichi&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-aichi/",
        }
      },
      {
        name: '三重県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=mie&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-mie/",
        }
      },
      {
        name: '滋賀県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=shiga&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-shiga/",
        }
      },
      {
        name: '京都府',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=kyoto&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-kyoto/",
        }
      },
      {
        name: '大阪府',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=osaka&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-osaka/",
        }
      },
      {
        name: '兵庫県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=hyogo&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-hyogo/",
        }
      },
      {
        name: '奈良県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=nara&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-nara/",
        }
      },
      {
        name: '和歌山県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=wakayama&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-wakayama/",
        }
      },
      {
        name: '鳥取県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=tottori&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-tottori/",
        }
      },
      {
        name: '島根県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=simane&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-shimane/",
        }
      },
      {
        name: '岡山県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=okayama&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-okayama/",
        }
      },
      {
        name: '広島県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=hiroshima&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-hiroshima/",
        }
      },
      {
        name: '山口県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=yamaguchi&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-yamaguchi/",
        }
      },
      {
        name: '徳島県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=tokushima&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-tokushima/",
        }
      },
      {
        name: '香川県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=kagawa&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-kagawa/",
        }
      },
      {
        name: '愛媛県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=ehime&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-ehime/",
        }
      },
      {
        name: '高知県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=kouchi&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-kochi/",
        }
      },
      {
        name: '福岡県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=hukuoka&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-fukuoka/",
        }
      },
      {
        name: '佐賀県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=saga&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-saga/",
        }
      },
      {
        name: '長崎県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=nagasaki&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-nagasaki/",
        }
      },
      {
        name: '熊本県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=nagasaki&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-kumamoto/",
        }
      },
      {
        name: '大分県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=ooita&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-oita/",
        }
      },
      {
        name: '宮崎県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=miyazaki&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-miyazaki/",
        }
      },
      {
        name: '鹿児島県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=kagoshima&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-kagoshima/",
        }
      },
      {
        name: '沖縄県',
        links: {
          hotel: "https://search.travel.rakuten.co.jp/ds/undated/search?f_dai=japan&f_landmark_id=&f_ido=0&f_kdo=0&f_latitude=0&f_longitude=0&f_teikei=&f_disp_type=&f_sort=hotel&f_rm_equip=&f_page=1&f_hyoji=30&f_image=1&f_tab=hotel&f_setubi=&f_point_min=0&f_datumType=&f_cok=&f_chu=okinawa&f_shou=&f_sai=&f_dist=&f_cd=02&f_campaign=20allgoto2009dh-02&f_layout=list",
          spot: "https://travel.rakuten.co.jp/mytrip/ranking/spot-okinawa/",
        }
      },
    ]
  end

end
