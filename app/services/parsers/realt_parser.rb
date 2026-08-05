module Parsers
  class RealtParser
    BASE_URL = 'https://realt.by'.freeze

    def self.parse(url)
      new.parse(url)
    end

    def parse(url)
      doc = fetch_page(url)

      ad_elements = doc.xpath('//a[starts-with(@href, "/rent-cottage-for-long/object/")]/..')

      ad_elements.each do |card|
        link_node = card.at_xpath('.//a[starts-with(@href, "/rent-cottage-for-long/object/")]')
        next unless link_node

        href = link_node['href']
        external_id = href.match(%r{/object/(\d+)})&.captures&.first
        next unless external_id

        full_url = URI.join(BASE_URL, href).to_s

        price_node = card.at_xpath('.//span[contains(@class, "text-title") and contains(@class, "font-semibold")]')
        price_text = price_node&.text&.strip
        price = extract_price(price_text)

        address_node = card.at_xpath('.//p[contains(@class, "text-basic") and contains(@class, "text-subhead")]')
        address = address_node&.text&.strip

        description_node = card.at_xpath('.//span[contains(@class, "line-clamp")]')
        description = description_node&.text&.strip

        published_at = Time.current
        title = "Объявление #{external_id}"

        # 👇 Получаем фото отдельным запросом
        photos = fetch_photos_from_details(full_url)

        ad_attrs = {
          external_id: external_id,
          site: 'realt',
          url: full_url,
          title: title,
          price: price,
          address: address,
          description: description,
          published_at: published_at,
          photos: photos
        }

        save_ad(ad_attrs)
      end
    end

    private

    def fetch_page(url)
      response = Faraday.get(url)
      Nokogiri::HTML(response.body)
    end

    def fetch_photos_from_details(url)
      doc = fetch_page(url)
      # Берём все img, чей src содержит путь к фото на CDN
      doc.css('img[src*="cdn.realt.by/img/"]').map { |img| img['src'] }.compact.uniq[..9] # first 10 only
    rescue => e
      Rails.logger.warn "Не удалось загрузить фото для #{url}: #{e.message}"
      []
    end

    def extract_price(text)
      return nil if text.blank?
      cleaned = text.gsub(/[^\d\s.,]/, '').strip
      number = cleaned[/[\d.,]+/]
      return nil unless number
      number.gsub!(/\s/, '')
      number.gsub!(',', '.') if number.include?(',')
      number.to_f.round
    rescue
      0.0
    end

    def save_ad(attributes)
      ad = Ad.find_or_initialize_by(
        site: 'realt',
        external_id: attributes[:external_id]
      )

      if ad.new_record?
        ad.assign_attributes(attributes)
        if ad.valid?
          ad.save!
          notify_telegram(ad)
        end
      else
        unless price_range(ad).include?(attributes[:price])
          old_price = ad.price
          ad.assign_attributes(attributes)
          if ad.valid?
            ad.save!
            notify_telegram(ad, old_price:)
          end
        end
      end
    end

    def price_range(ad)
      (ad.price - 135..ad.price + 135)
    end

    def notify_telegram(ad, old_price: false)
      Telegram::TelegramNotifier.notify_new_ad(ad, old_price:)
    end
  end
end
