require 'telegram/bot'

module Telegram
  class TelegramNotifier
    TOKEN = ENV['TELEGRAM_BOT_TOKEN']
    CHAT_ID = ENV['TELEGRAM_CHAT_ID']
    CHAT_ID_FOR_SELL = ENV['TELEGRAM_CHAT_ID_FOR_SELL']

    def self.client
      @client ||= Telegram::Bot::Client.new(TOKEN)
    end

    def self.notify_new_ad(ad, old_price: nil, use_for_sell_chat: false)
      caption = format_message(ad, old_price)
      photos = ad.photos || []

      if photos.any?
        media = photos.first(10).map.with_index do |photo_url, index|
          item = {
            type: 'photo',
            media: photo_url
          }
          if index == 0
            item[:caption] = caption
            item[:parse_mode] = 'HTML'
          end
          item
        end
        send_media_group(media, use_for_sell_chat:)
      else
        send_message(caption, use_for_sell_chat:)
      end
    end

    def self.send_message(text, use_for_sell_chat: false)
      client.api.send_message(
        chat_id: use_for_sell_chat.present? ? CHAT_ID_FOR_SELL : CHAT_ID,
        text: text,
        parse_mode: 'HTML'
      )
    end

    def self.send_media_group(media, use_for_sell_chat: false)
      client.api.send_media_group(
        chat_id: use_for_sell_chat.present? ? CHAT_ID_FOR_SELL : CHAT_ID,
        media: media
      )
    end

    def self.format_message(ad, old_price = nil)
      header = old_price.present? ? "Цена изменилась! Старая цена: #{old_price}" : 'Новое объявление!'
      source = ad.url.include?('kufar') ? 'Kufar' : 'Realt'
      price_in_usd  = (ad.price.to_f / 2.93).to_i

      <<~MSG
      🏠 <b>#{header}</b>\n
      🧾 #{ad.title}\n
      🌐 Источник: #{source}\n
      💰 #{ad.price} руб. (~$#{price_in_usd})\n
      📍 #{ad.address}\n
      🕐 Время парсинга: #{ad.published_at.in_time_zone('Europe/Minsk').strftime('%d.%m.%Y %H:%M')}\n
      📝 #{ad.description}\n
      🔗 <a href="#{ad.url}">Ссылка на объявление</a>\n
    MSG
    end
  end
end
