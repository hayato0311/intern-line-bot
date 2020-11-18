require 'line/bot'

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

    events = client.parse_events_from(body)
    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          if event.message['text'] == '東京都' then
            message = {
              type: 'text',
              text: "2020/11/18の感染者数\n200人\n累計感染者数\n4000人"
            }
            client.reply_message(event['replyToken'], message)
          else
            message = {
              type: 'text',
              text: '「東京都」と入力してください。'
            }
            client.reply_message(event['replyToken'], message)
          end
        else
          message = {
            type: 'text',
            text: '「東京都」と入力してください。'
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    }
    head :ok
  end
end
